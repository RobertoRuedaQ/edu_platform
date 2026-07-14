require "test_helper"

class Core::RosterImport::Strategies::GuardiansTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "rig-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_batch(institution, kind:)
    term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
      starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: kind)
  end

  def create_student!(institution, national_id:, code:)
    GroupManagement::Student.create!(institution: institution, national_id: national_id,
      first_name: "Est", last_name: "Prueba", gender: "male", birthdate: Date.new(2015, 1, 1),
      student_code: code, entry_year: 2026)
  end

  def parse_and_validate(batch, content)
    Core::RosterImport::Parser.call(batch: batch, content: content)
    Core::RosterImport::Validator.call(batch: batch)
  end

  GUARDIAN_HEADER = "guardian_national_id,guardian_first_name,guardian_last_name,guardian_email,relationship,student_national_id\n"

  test "a brand-new guardian with a new child is marked valid" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n")

      assert_equal "valid", batch.roster_import_rows.first.status
    end
  end

  test "a guardian with two children is TWO valid rows, not a collision" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      create_student!(institution, national_id: "S-2", code: "COD-S2")
      batch = build_batch(institution, kind: "guardians")
      content = GUARDIAN_HEADER +
        "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n" \
        "G-1,Marta,Gómez,marta@correo.test,madre,S-2\n"
      parse_and_validate(batch, content)

      statuses = batch.roster_import_rows.order(:line_number).pluck(:status)
      assert_equal %w[valid valid], statuses
    end
  end

  test "the SAME (guardian, student) pair repeated in the file IS a collision" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      content = GUARDIAN_HEADER +
        "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n" \
        "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n"
      parse_and_validate(batch, content)

      statuses = batch.roster_import_rows.order(:line_number).pluck(:status)
      assert_equal %w[collision collision], statuses
    end
  end

  test "a link that already exists is marked duplicate" do
    institution = build_institution

    within_tenant(institution) do
      student = create_student!(institution, national_id: "S-1", code: "COD-S1")
      guardian = Core::User.create!(email: "marta@correo.test", name: "Marta Gómez", national_id: "G-1")
      institution.memberships.create!(user: guardian)
      Core::GuardianStudent.create!(institution: institution, guardian_user_id: guardian.id,
        student_id: student.id, relationship: "madre")

      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n")

      assert_equal "duplicate", batch.roster_import_rows.first.status
    end
  end

  test "a student_national_id that doesn't exist is an error" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,NOPE\n")

      row = batch.roster_import_rows.first
      assert_equal "error", row.status
      assert_match(/estudiante no encontrado/, row.message)
    end
  end

  test "an invalid relationship is an error" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,vecina,S-1\n")

      row = batch.roster_import_rows.first
      assert_equal "error", row.status
      assert_match(/relationship/, row.message)
    end
  end

  test "a missing guardian_email is an error" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,,madre,S-1\n")

      row = batch.roster_import_rows.first
      assert_equal "error", row.status
      assert_match(/guardian_email/, row.message)
    end
  end

  test "validating makes zero writes to users, institution_users, or guardian_students" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n")

      assert_equal 0, Core::User.count
      assert_equal 0, Core::InstitutionUser.count
      assert_equal 0, Core::GuardianStudent.count
    end
  end

  test "commit creates the guardian (no password), a membership with zero role_assignments, and the link" do
    institution = build_institution

    within_tenant(institution) do
      student = create_student!(institution, national_id: "S-1", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n")

      Core::RosterImport::Committer.call(batch: batch)

      guardian = Core::User.find_by(national_id: "G-1")
      assert guardian.present?
      assert_nil guardian.password_digest
      assert_equal "marta@correo.test", guardian.email

      membership = Core::InstitutionUser.find_by(institution: institution, user: guardian)
      assert membership.present?
      assert membership.active?

      assert_equal 0, IdentityAccess::RoleAssignment.where(institution_user_id: membership.id).count

      link = Core::GuardianStudent.find_by(institution: institution, guardian_user_id: guardian.id, student_id: student.id)
      assert link.present?
      assert_equal "madre", link.relationship
      assert_equal "active", link.status
      assert_equal link.id, batch.roster_import_rows.first.reload.resolved_record_id
    end
  end

  test "commit for two children of the same guardian creates ONE user and TWO links" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      create_student!(institution, national_id: "S-2", code: "COD-S2")
      batch = build_batch(institution, kind: "guardians")
      content = GUARDIAN_HEADER +
        "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n" \
        "G-1,Marta,Gómez,marta@correo.test,madre,S-2\n"
      parse_and_validate(batch, content)

      Core::RosterImport::Committer.call(batch: batch)

      assert_equal 1, Core::User.where(national_id: "G-1").count
      guardian = Core::User.find_by(national_id: "G-1")
      assert_equal 2, Core::GuardianStudent.where(guardian_user_id: guardian.id).count
    end
  end

  # --- THE crown test: additive, never destructive (G4) -----------------------

  test "a preexisting link to a student NOT in the CSV is preserved after commit" do
    institution = build_institution

    within_tenant(institution) do
      student_in_csv = create_student!(institution, national_id: "S-1", code: "COD-S1")
      student_not_in_csv = create_student!(institution, national_id: "S-2", code: "COD-S2")

      guardian = Core::User.create!(email: "marta@correo.test", name: "Marta Gómez", national_id: "G-1")
      institution.memberships.create!(user: guardian)
      preexisting_link = Core::GuardianStudent.create!(institution: institution, guardian_user_id: guardian.id,
        student_id: student_not_in_csv.id, relationship: "madre")

      batch = build_batch(institution, kind: "guardians")
      # This CSV only mentions S-1 — S-2's link must survive untouched.
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n")
      Core::RosterImport::Committer.call(batch: batch)

      assert Core::GuardianStudent.exists?(id: preexisting_link.id), "the link absent from the CSV was destroyed"
      assert Core::GuardianStudent.exists?(guardian_user_id: guardian.id, student_id: student_in_csv.id)
      assert_equal 2, Core::GuardianStudent.where(guardian_user_id: guardian.id).count
    end
  end

  test "re-committing the same batch does not duplicate the guardian or the link" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "S-1", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n")

      Core::RosterImport::Committer.call(batch: batch)
      Core::RosterImport::Committer.call(batch: batch)

      assert_equal 1, Core::User.where(national_id: "G-1").count
      assert_equal 1, Core::GuardianStudent.count
    end
  end

  test "a revoked link is reactivated by a re-import that mentions it" do
    institution = build_institution

    within_tenant(institution) do
      student = create_student!(institution, national_id: "S-1", code: "COD-S1")
      guardian = Core::User.create!(email: "marta@correo.test", name: "Marta Gómez", national_id: "G-1")
      institution.memberships.create!(user: guardian)
      link = Core::GuardianStudent.create!(institution: institution, guardian_user_id: guardian.id,
        student_id: student.id, relationship: "madre", status: "revoked")

      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch, GUARDIAN_HEADER + "G-1,Marta,Gómez,marta@correo.test,madre,S-1\n")
      Core::RosterImport::Committer.call(batch: batch)

      assert_equal "active", link.reload.status
    end
  end

  test "national_id (guardian and student) is encrypted in the row, never stored in the clear" do
    institution = build_institution

    within_tenant(institution) do
      create_student!(institution, national_id: "1234567890", code: "COD-S1")
      batch = build_batch(institution, kind: "guardians")
      parse_and_validate(batch,
        GUARDIAN_HEADER + "9876543210,Marta,Gómez,marta@correo.test,madre,1234567890\n")

      row = batch.roster_import_rows.first
      assert_not row.raw["guardian_national_id"].to_s.include?("9876543210")
      assert_not row.raw["student_national_id"].to_s.include?("1234567890")
      assert_equal "9876543210", Core::RosterImport::Cipher.decrypt(row.raw["guardian_national_id"])
      assert_equal "1234567890", Core::RosterImport::Cipher.decrypt(row.raw["student_national_id"])
    end
  end
end
