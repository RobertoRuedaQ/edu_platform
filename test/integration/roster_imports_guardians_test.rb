require "test_helper"

class RosterImportsGuardiansTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { @user, @institution = sign_in_as_member }

  def as_people_manager(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[people.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def within_tenant(&block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      block.call
    end
  end

  def ensure_active_term!
    within_tenant do
      Core::AcademicTerm.find_or_create_by!(institution: @institution, code: "2026-1") do |t|
        t.name = "2026-1"
        t.starts_on = Date.new(2026, 1, 1)
        t.ends_on = Date.new(2026, 6, 30)
        t.status = "active"
      end
    end
  end

  def upload(content)
    file = Tempfile.new([ "guardians", ".csv" ])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv")
  end

  def create_student!(national_id:, code:)
    within_tenant do
      GroupManagement::Student.create!(institution: @institution, national_id: national_id,
        first_name: "Est", last_name: "Prueba", gender: "male", birthdate: Date.new(2015, 1, 1),
        student_code: code, entry_year: 2026)
    end
  end

  GUARDIAN_HEADER = "guardian_national_id,guardian_first_name,guardian_last_name,guardian_email,relationship,student_national_id\n"

  test "acceptance: upload -> preview (no writes) -> commit -> real guardian+links, additive, idempotent, private, zero RBAC" do
    ensure_active_term!
    student_a = create_student!(national_id: "S-A", code: "ACC-A")
    student_b = create_student!(national_id: "S-B", code: "ACC-B")

    # A guardian who ALREADY exists, with TWO pre-existing links: one to a
    # THIRD student the CSV never mentions (the crown test — must survive
    # untouched), and one to student_a that the CSV DOES re-affirm (the real
    # "duplicate" — link-already-exists — path, not merely "guardian exists").
    existing_guardian = within_tenant do
      student_c = GroupManagement::Student.create!(institution: @institution, national_id: "S-C",
        first_name: "Otro", last_name: "Estudiante", gender: "female", birthdate: Date.new(2014, 1, 1),
        student_code: "ACC-C", entry_year: 2026)
      guardian = Core::User.create!(email: "existente@correo.test", name: "Ya Existe", national_id: "G-EXISTING")
      @institution.memberships.create!(user: guardian)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: guardian.id,
        student_id: student_c.id, relationship: "padre")
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: guardian.id,
        student_id: student_a.id, relationship: "padre")
      guardian
    end

    as_people_manager do
      content = GUARDIAN_HEADER +
        "G-NEW,Marta,Gómez,marta@correo.test,madre,S-A\n" \
        "G-NEW,Marta,Gómez,marta@correo.test,madre,S-B\n" \
        "G-EXISTING,Ya,Existe,existente@correo.test,padre,S-A\n" \
        "G-ERR1,Falla,Uno,sinestudiante@correo.test,padre,NOPE\n" \
        "G-ERR2,Falla,Dos,,padre,S-A\n"

      post "/identity_access/roster_imports", params: { roster_import: { kind: "guardians", file: upload(content) } }
      assert_redirected_to identity_access_roster_import_path(Core::RosterImportBatch.last)
      follow_redirect!
      assert_response :success
      assert_no_match(/G-NEW|G-EXISTING|G-ERR|S-A|S-B/, response.body)

      batch = within_tenant { Core::RosterImportBatch.last }
      within_tenant do
        assert_equal "validated", batch.reload.status
        assert_equal 2, batch.summary["create_count"]  # the two G-NEW rows
        assert_equal 1, batch.summary["update_count"]  # G-EXISTING re-affirming its EXISTING link to S-A
        assert_equal 2, batch.summary["error_count"]
        assert_equal 0, Core::User.where.not(id: [ existing_guardian.id, @user.id ]).count # no new users yet
        assert_equal 2, Core::GuardianStudent.count # only the two pre-existing links (S-C, S-A)
      end

      perform_enqueued_jobs { post commit_identity_access_roster_import_path(batch) }
      assert_redirected_to identity_access_roster_import_path(batch)

      new_guardian = within_tenant do
        assert_equal "committed", batch.reload.status
        g = Core::User.find_by(national_id: "G-NEW")
        assert g.present?
        assert_nil g.password_digest # invitation issued, but never sets a password directly
        membership = Core::InstitutionUser.find_by(institution: @institution, user: g)
        assert membership.active?
        assert_equal 0, IdentityAccess::RoleAssignment.where(institution_user_id: membership.id).count
        assert_equal 2, Core::GuardianStudent.where(guardian_user_id: g.id).count
        g
      end

      # Batch-invite (OPEN_PROCESS.md, closed): the REAL new guardian gets
      # exactly ONE invitation — one row despite having TWO CSV rows
      # (S-A, S-B), because Resolver only returns new_user: true on
      # whichever row commits first (line_number order). Attributed to
      # whoever uploaded the batch (Current.institution_user, via
      # as_people_manager), never nil when a real actor exists.
      within_tenant do
        invitations = IdentityAccess::Invitation.where(institution: @institution, user: new_guardian)
        assert_equal 1, invitations.count
        assert_equal @user.id, invitations.sole.created_by.user_id
      end

      # G-EXISTING already existed before this batch (test setup) — never
      # re-invited just because a CSV row re-affirms their link.
      within_tenant do
        assert_equal 0, IdentityAccess::Invitation.where(institution: @institution, user: existing_guardian).count
      end

      # The crown test: the pre-existing link to student_c (never in the CSV) survives.
      within_tenant do
        assert Core::GuardianStudent.exists?(guardian_user_id: existing_guardian.id,
          student_id: GroupManagement::Student.find_by(national_id: "S-C").id)
        assert_equal 2, Core::GuardianStudent.where(guardian_user_id: existing_guardian.id).count # old + new (S-A)
      end

      # Idempotency: re-commit does not duplicate — including never a second invitation.
      perform_enqueued_jobs { post commit_identity_access_roster_import_path(batch) }
      within_tenant do
        assert_equal 1, Core::User.where(national_id: "G-NEW").count
        # existing_guardian: S-C (pre-existing) + S-A (new) = 2; new_guardian: S-A + S-B = 2.
        assert_equal 4, Core::GuardianStudent.count
        assert_equal 1, IdentityAccess::Invitation.where(institution: @institution, user: new_guardian).count
      end

      # Privacy: no plaintext national_id anywhere in the rows.
      within_tenant do
        batch.roster_import_rows.each do |row|
          assert_not row.raw["guardian_national_id"].to_s.match?(/G-NEW|G-EXISTING|G-ERR/)
          assert_not row.raw["student_national_id"].to_s.match?(/S-A|S-B/)
        end
      end
    end
  end

  test "an actor without people.manage is denied uploading guardians with a friendly 403" do
    ensure_active_term!

    with_grants do
      post "/identity_access/roster_imports", params: { roster_import: { kind: "guardians", file: upload(GUARDIAN_HEADER) } }
      assert_response :forbidden
    end
  end
end
