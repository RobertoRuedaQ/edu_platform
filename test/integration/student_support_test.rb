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

  # --- disciplinary_logs (convivencia) ---------------------------------------

  test "disciplinary log index/create are scoped to the student's group" do
    as_counselor_9a do
      get "/student_support/students/s-3/disciplinary_logs" # s-3 is in stub-section-9a
      assert_response :success

      get "/student_support/students/s-9/disciplinary_logs" # s-9 is in stub-section-11b
      assert_response :forbidden
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
    # real to count (student_support's own accommodations/disciplinary_logs
    # stay stub, Class C, unaffected).
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
    # #4 barrido (v1.14.0) — student_support's own Convivencia/Acomodaciones
    # panels stay on their pre-existing stub (student_support has no real
    # disciplinary_logs/accommodations table at all, Class C), gated by can?
    # against this real student's real group_id.
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
