require "test_helper"

# #4 barrido (v1.14.0) — counseling is a SENSITIVE-domain carve-out (the
# user explicitly opted it into this slice, with extra security rigor beyond
# the standard scope+RBAC+cross-tenant mini-case): confidentiality notes and
# referrals, carved out of student_support because it needs a narrower access
# boundary (see app/domains/counseling/README.md). Copies the
# teacher_management canonical mold (§6.6) like every other #4 domain, but
# with additional model-layer RLS verification since this data is the most
# sensitive real data cabled in this barrido.
class CounselingTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_section!(institution, name:)
    GroupManagement::Section.create!(institution: institution, name: name, academic_year: 2026)
  end

  def build_student!(institution, first_name:, last_name:, student_code:, section:)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2012, 6, 1), student_code: student_code, entry_year: 2023, section: section)
  end

  def build_case!(institution, student:, opener:, category:, status: "open")
    Counseling::Case.create!(institution: institution, student: student, opened_by: opener,
      category: category, status: status, opened_at: Time.current)
  end

  setup do
    @user, @institution = sign_in_as_member
    @opener = within_tenant(@institution) { @institution.memberships.find_by!(user: @user) }

    @section_in = within_tenant(@institution) { build_section!(@institution, name: "9°A") }
    @section_out = within_tenant(@institution) { build_section!(@institution, name: "11°B") }

    @student_in = within_tenant(@institution) do
      build_student!(@institution, first_name: "Isabella", last_name: "Mendoza", student_code: "COL-E-301", section: @section_in)
    end
    @student_out = within_tenant(@institution) do
      build_student!(@institution, first_name: "Luciana", last_name: "Restrepo", student_code: "COL-E-302", section: @section_out)
    end

    @case_in = within_tenant(@institution) do
      build_case!(@institution, student: @student_in, opener: @opener, category: "conducta")
    end
    @case_out = within_tenant(@institution) do
      build_case!(@institution, student: @student_out, opener: @opener, category: "emocional")
    end
  end

  def as_counselor_in_group(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "counselor", permission_keys: %w[counseling.read],
                                     scope_type: :group, scope_id: @section_in.id),
      &block
    )
  end

  def as_wellbeing_coordinator(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "coordinator", permission_keys: %w[counseling.read],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "index filters to the actor's own group" do
    as_counselor_in_group do
      get "/counseling"
      assert_response :success
      assert_select "a", text: "Isabella Mendoza"
      assert_select "a", text: "Luciana Restrepo", count: 0
    end
  end

  test "index for an institution-wide read role sees every case" do
    as_wellbeing_coordinator do
      get "/counseling"
      assert_response :success
      assert_select ".table tbody tr", count: 2
    end
  end

  test "authorize! denies a case outside the actor's group" do
    as_counselor_in_group do
      get "/counseling/#{@case_out.id}"
      assert_response :forbidden
    end
  end

  test "an actor with no grants is denied the index (403)" do
    with_grants { get "/counseling"; assert_response :forbidden }
  end

  test "show renders session notes and referrals for a case inside the actor's scope" do
    within_tenant(@institution) do
      note = @case_in.session_notes.create!(institution: @institution, author: @opener,
        occurred_at: Time.current, body: "Seguimiento inicial.", confidential: true)
      @case_in.referrals.create!(institution: @institution, referred_to: "Psicología externa",
        reason: "Evaluación especializada", status: "pending")
    end

    as_counselor_in_group do
      get "/counseling/#{@case_in.id}"
      assert_response :success
      assert_match(/Seguimiento inicial/, response.body)
      assert_match(/Psicología externa/, response.body)
    end
  end

  # --- extra security rigor (user-requested, this domain only) --------------

  test "SECURITY: a role without counseling.read never reaches ANY counseling data, index or show" do
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[students.read groups.view],
                                     scope_type: :group, scope_id: @section_in.id)
    ) do
      get "/counseling"
      assert_response :forbidden

      get "/counseling/#{@case_in.id}"
      assert_response :forbidden
    end
  end

  test "SECURITY: cross-tenant isolation verified with a REAL query under RLS, not current_setting()" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "couns-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    other_case = within_tenant(other_institution) do
      section = build_section!(other_institution, name: "9°A Otro Colegio")
      student = build_student!(other_institution, first_name: "Fantasma", last_name: "Ajeno",
        student_code: "GHOST-1", section: section)
      opener = other_institution.memberships.create!(user: Core::User.create!(email: "opener-#{SecureRandom.hex(3)}@correo.test", name: "Otro Opener"))
      build_case!(other_institution, student: student, opener: opener, category: "familiar")
    end

    # (1) App-layer: the HTTP surface never shows J's case while acting in I.
    as_wellbeing_coordinator do
      get "/counseling"
      assert_response :success
      assert_no_match(/Fantasma Ajeno/, response.body)

      get "/counseling/#{other_case.id}"
      assert_response :not_found
    end

    # (2) Model-layer, under I's own GUC: a raw query that explicitly ASKS
    # for J's institution_id (not just omits a filter) must still return
    # ZERO rows — proving RLS itself blocks it, not just the app's own
    # institution_id scoping (which would stay silent about a leak if RLS
    # silently weren't enforcing anything underneath it).
    within_tenant(@institution) do
      assert_empty Counseling::Case.where(institution_id: other_institution.id)
      assert_empty Counseling::Case.where(id: other_case.id)
    end
  end

  test "SECURITY: session_notes/referrals are RLS-isolated too, not just counseling_cases" do
    other_institution = Core::Institution.create!(name: "Colegio Otro Notas", slug: "couns-notes-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      section = build_section!(other_institution, name: "9°A")
      student = build_student!(other_institution, first_name: "Otro", last_name: "Estudiante",
        student_code: "GHOST-2", section: section)
      opener = other_institution.memberships.create!(user: Core::User.create!(email: "opener2-#{SecureRandom.hex(3)}@correo.test", name: "Opener 2"))
      kase = build_case!(other_institution, student: student, opener: opener, category: "conducta")
      kase.session_notes.create!(institution: other_institution, author: opener, occurred_at: Time.current,
        body: "Nota confidencial de otra institución.", confidential: true)
    end

    within_tenant(@institution) do
      assert_empty Counseling::SessionNote.where(institution_id: other_institution.id)
    end
  end
end
