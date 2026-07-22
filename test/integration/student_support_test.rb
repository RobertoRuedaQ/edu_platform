require "test_helper"

class StudentSupportTest < ActionDispatch::IntegrationTest
  setup { @user, @institution = sign_in_as_member }

  # Counselor scoped to 9°A only: full wellbeing toolkit, but the NARROW
  # medical tier (summary, not the owner's full record).
  def as_counselor_9a(&block)
    with_grants(
      Authorization::Assignment.new(
        role_key: "counselor",
        permission_keys: %w[students.read counseling.read medical_history.view_summary
                             accommodations.view disciplinary_logs.manage support_dashboard.view],
        scope_type: :group, scope_id: GroupManagement::GroupRoster::SECTION_9A_ID
      ), &block
    )
  end

  # Medical staff, institution-wide, full clinical record — the owner tier.
  def as_medical_staff(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "medical_staff", permission_keys: %w[medical_history.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # Coordinator: manages accommodations/convivencia institution-wide, but
  # never touches counseling (a distinct, narrower specialty).
  def as_coordinator(&block)
    with_grants(
      Authorization::Assignment.new(
        role_key: "coordinator",
        permission_keys: %w[accommodations.view accommodations.manage
                             disciplinary_logs.manage support_dashboard.view],
        scope_type: :institution, scope_id: nil
      ), &block
    )
  end

  # Homeroom: read-only on accommodations (Apéndice A: "homeroom(lectura)").
  def as_homeroom_readonly(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[accommodations.view],
                                     scope_type: :group, scope_id: GroupManagement::GroupRoster::SECTION_9A_ID),
      &block
    )
  end

  # counseling's own tests (real Case/SessionNote/Referral data since #4
  # barrido, v1.14.0) moved to test/integration/counseling_test.rb — this
  # file used to hold them from before counseling was carved out as its own
  # domain.

  # --- medical_history: two tiers of the same resource -----------------------

  test "medical_staff sees the full clinical record" do
    as_medical_staff do
      get "/student_support/students/s-1/medical_history"
      assert_response :success
      assert_select "dd", text: /Asma leve/
    end
  end

  test "counselor sees only the allergy summary, never the full record" do
    as_counselor_9a do
      get "/student_support/students/s-1/medical_history" # s-1 is in stub-section-9a
      assert_response :success
      assert_select ".allergen__name", text: "Maní"
      assert_select "dd", text: /Asma leve/, count: 0
    end
  end

  test "counselor is denied medical history outside their own group" do
    as_counselor_9a do
      get "/student_support/students/s-4/medical_history" # s-4 is in stub-section-10a
      assert_response :forbidden
    end
  end

  test "an actor with neither medical tier is denied" do
    as_coordinator do
      get "/student_support/students/s-1/medical_history"
      assert_response :forbidden
    end
  end

  # --- accommodations: view vs manage ----------------------------------------

  test "accommodations index is scoped by the student's group" do
    as_counselor_9a do
      get "/student_support/students/s-1/accommodations" # s-1 is in stub-section-9a
      assert_response :success

      get "/student_support/students/s-4/accommodations" # s-4 is in stub-section-10a
      assert_response :forbidden
    end
  end

  test "can? shows 'Editar' only for a role holding accommodations.manage" do
    as_coordinator do
      get "/student_support/students/s-1/accommodations"
      assert_select "a.btn", text: "Editar"
    end

    as_homeroom_readonly do
      get "/student_support/students/s-1/accommodations"
      assert_response :success
      assert_select "a.btn", text: "Editar", count: 0
    end
  end

  test "authorize! denies editing an accommodation for a read-only role, matching can?" do
    as_homeroom_readonly do
      get "/student_support/students/s-1/accommodations/acc-1/edit"
      assert_response :forbidden
    end
  end

  test "coordinator can edit an accommodation" do
    as_coordinator do
      get "/student_support/students/s-1/accommodations/acc-1/edit"
      assert_response :success
    end
  end

  # --- disciplinary_logs (convivencia) — REAL since guidelines/CLOSURE_PLAN.md
  # Fase B (StudentSupport::DisciplinaryLog replaces the DisciplinaryLogRoster
  # stub). Real students in real sections, not the old stub string ids.

  def build_real_students
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      section_9a = GroupManagement::Section.find_or_create_by!(id: GroupManagement::GroupRoster::SECTION_9A_ID) do |s|
        s.institution = @institution
        s.name = "9°A"
        s.academic_year = 2026
      end
      section_11b = GroupManagement::Section.find_or_create_by!(id: GroupManagement::GroupRoster::SECTION_11B_ID) do |s|
        s.institution = @institution
        s.name = "11°B"
        s.academic_year = 2026
      end
      in_scope = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "P",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "DISC-IN", entry_year: 2023, section: section_9a)
      out_of_scope = GroupManagement::Student.create!(institution: @institution, first_name: "Leo", last_name: "P",
        gender: "male", birthdate: Date.new(2013, 3, 1), student_code: "DISC-OUT", entry_year: 2023, section: section_11b)
      [ in_scope, out_of_scope ]
    end
  end

  test "disciplinary log index/create are scoped to the student's group" do
    in_scope, out_of_scope = build_real_students

    as_counselor_9a do
      get "/student_support/students/#{in_scope.id}/disciplinary_logs"
      assert_response :success

      get "/student_support/students/#{out_of_scope.id}/disciplinary_logs"
      assert_response :forbidden
    end
  end

  test "recording a disciplinary log persists for real, is audited, and appears in the timeline" do
    in_scope, _out_of_scope = build_real_students

    as_counselor_9a do
      assert_difference -> { StudentSupport::DisciplinaryLog.count }, 1 do
        assert_difference -> { IdentityAccess::AuditEvent.where(action: "disciplinary_log.recorded").count }, 1 do
          post "/student_support/students/#{in_scope.id}/disciplinary_logs",
            params: { category: "conduct", description: "Conflicto verbal con un compañero.", occurred_at: Date.current }
        end
      end
      assert_response :redirect
      follow_redirect!
      assert_match "Conflicto verbal", response.body
    end
  end

  test "an invalid category is rejected with a friendly error, never a 500" do
    in_scope, = build_real_students

    as_counselor_9a do
      assert_no_difference -> { StudentSupport::DisciplinaryLog.count } do
        post "/student_support/students/#{in_scope.id}/disciplinary_logs",
          params: { category: "invented", description: "x", occurred_at: Date.current }
      end
      assert_response :unprocessable_entity
    end
  end

  # --- support_dashboard: each section respects ITS OWN permission -----------

  test "support_dashboard denies an actor without support_dashboard.view" do
    with_grants(
      Authorization::Assignment.new(role_key: "nobody", permission_keys: %w[counseling.read],
                                     scope_type: :institution, scope_id: nil)
    ) { get "/student_support/dashboard"; assert_response :forbidden }
  end

  test "support_dashboard never leaks counseling data to a role without counseling.read" do
    as_coordinator do
      get "/student_support/dashboard"
      assert_response :success
      # coordinator holds support_dashboard.view but NOT counseling.read.
      assert_select ".empty-state__title", text: "Sin casos abiertos en tu alcance"
    end
  end

  test "support_dashboard shows scoped counts for a role holding all three permissions" do
    # Counseling::Case is real since #4 barrido (v1.14.0) — seed one open
    # case in the actor's own group so the dashboard's stat has something
    # real to count (accommodations stays stub, Class C, unaffected;
    # disciplinary_logs is real since guidelines/CLOSURE_PLAN.md Fase B but
    # this test seeds none, so its stat stays "0").
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      section = GroupManagement::Section.find_or_create_by!(id: GroupManagement::GroupRoster::SECTION_9A_ID) do |s|
        s.institution = @institution
        s.name = "9°A"
        s.academic_year = 2026
      end
      student = GroupManagement::Student.create!(institution: @institution, first_name: "Isabella", last_name: "Mendoza",
        gender: "female", birthdate: Date.new(2012, 5, 1), student_code: "COL-E-DASH", entry_year: 2023, section: section)
      opener = @institution.memberships.find_by!(user: @user)
      Counseling::Case.create!(institution: @institution, student: student, opened_by: opener,
        category: "conducta", status: "open", opened_at: Time.current)
    end

    as_counselor_9a do
      get "/student_support/dashboard"
      assert_response :success
      assert_select ".stat__value", text: "1" # the one open case just seeded, in the actor's own group
    end
  end

  # --- retrofit: group_management students#show gains Convivencia/Acomodaciones --

  test "students#show exposes Convivencia and Acomodaciones only with the matching permission" do
    # group_management#show reads a REAL GroupManagement::Student since the
    # #4 barrido (v1.14.0). Convivencia is REAL since guidelines/CLOSURE_PLAN.md
    # Fase B (StudentSupport::DisciplinaryLog); Acomodaciones stays on its
    # pre-existing stub (student_support has no real accommodations table yet,
    # Class C) — both gated by can? against this real student's real group_id.
    real_student = ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      section = GroupManagement::Section.find_or_create_by!(id: GroupManagement::GroupRoster::SECTION_9A_ID) do |s|
        s.institution = @institution
        s.name = "9°A"
        s.academic_year = 2026
      end
      GroupManagement::Student.create!(institution: @institution, first_name: "Isabella", last_name: "Mendoza",
        gender: "female", birthdate: Date.new(2012, 5, 1), student_code: "COL-E-RETROFIT", entry_year: 2023,
        section: section)
    end

    as_counselor_9a do
      get "/group_management/students/#{real_student.id}"
      assert_response :success
      assert_select ".tabs__tab", text: "Convivencia"
      assert_select ".tabs__tab", text: "Acomodaciones"
    end
  end
end
