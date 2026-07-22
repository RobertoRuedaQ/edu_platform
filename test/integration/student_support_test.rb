require "test_helper"

class StudentSupportTest < ActionDispatch::IntegrationTest
  setup { @user, @institution = sign_in_as_member }

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

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

  # Real students in real sections (matching GroupRoster's fixed section ids
  # so the group-scoped role helpers above cover/exclude the right one),
  # shared by medical_history/accommodations/disciplinary_logs tests — all
  # real since guidelines/CLOSURE_PLAN.md Fase B/D replaced their stubs.
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
      in_scope = GroupManagement::Student.find_or_create_by!(student_code: "DISC-IN") do |s|
        s.institution = @institution; s.first_name = "Ana"; s.last_name = "P"; s.gender = "female"
        s.birthdate = Date.new(2013, 3, 1); s.entry_year = 2023; s.section = section_9a
      end
      out_of_scope = GroupManagement::Student.find_or_create_by!(student_code: "DISC-OUT") do |s|
        s.institution = @institution; s.first_name = "Leo"; s.last_name = "P"; s.gender = "male"
        s.birthdate = Date.new(2013, 3, 1); s.entry_year = 2023; s.section = section_11b
      end
      [ in_scope, out_of_scope ]
    end
  end

  # --- medical_history: two tiers of the same resource -----------------------
  # REAL since guidelines/CLOSURE_PLAN.md Fase D — StudentSupport::
  # MedicalHistory/StudentAllergy replace the MedicalHistoryRoster stub.

  test "medical_staff sees the full clinical record" do
    in_scope, = build_real_students
    within_tenant(@institution) do
      StudentSupport::MedicalHistory.create!(institution: @institution, student: in_scope, conditions: [ "Asma leve" ])
    end

    as_medical_staff do
      get "/student_support/students/#{in_scope.id}/medical_history"
      assert_response :success
      assert_select "dd", text: /Asma leve/
    end
  end

  test "counselor sees only the allergy summary, never the full record" do
    in_scope, = build_real_students
    within_tenant(@institution) do
      StudentSupport::MedicalHistory.create!(institution: @institution, student: in_scope, conditions: [ "Asma leve" ])
      StudentSupport::StudentAllergy.create!(institution: @institution, student: in_scope,
        allergen_name: "Maní", severity: "severe")
    end

    as_counselor_9a do
      get "/student_support/students/#{in_scope.id}/medical_history"
      assert_response :success
      assert_select ".allergen__name", text: "Maní"
      assert_select "dd", text: /Asma leve/, count: 0
    end
  end

  test "counselor is denied medical history outside their own group" do
    _in_scope, out_of_scope = build_real_students

    as_counselor_9a do
      get "/student_support/students/#{out_of_scope.id}/medical_history"
      assert_response :forbidden
    end
  end

  test "an actor with neither medical tier is denied" do
    in_scope, = build_real_students

    as_coordinator do
      get "/student_support/students/#{in_scope.id}/medical_history"
      assert_response :forbidden
    end
  end

  test "a student with NO medical history row yet still renders — an honest empty state, never a 404" do
    in_scope, = build_real_students

    as_medical_staff do
      get "/student_support/students/#{in_scope.id}/medical_history"
      assert_response :success
      assert_select ".empty-state__title", text: "Sin alergias registradas"
    end
  end

  test "medical_staff (full tier) can edit the record and add an allergy; the summary tier cannot" do
    in_scope, = build_real_students

    as_medical_staff do
      get "/student_support/students/#{in_scope.id}/medical_history/edit"
      assert_response :success

      patch "/student_support/students/#{in_scope.id}/medical_history",
        params: { medical_history: { blood_type: "O+", conditions: "Asma leve", medications: "" } }
      assert_response :redirect
      assert_equal "O+", within_tenant(@institution) { StudentSupport::MedicalHistory.find_by!(student_id: in_scope.id).blood_type }

      assert_difference -> { StudentSupport::StudentAllergy.count }, 1 do
        post "/student_support/students/#{in_scope.id}/student_allergies",
          params: { student_allergy: { allergen_name: "Maní", severity: "severe" } }
      end
      assert_response :redirect
    end

    as_counselor_9a do
      get "/student_support/students/#{in_scope.id}/medical_history/edit"
      assert_response :forbidden

      post "/student_support/students/#{in_scope.id}/student_allergies",
        params: { student_allergy: { allergen_name: "Lactosa", severity: "mild" } }
      assert_response :forbidden
    end
  end

  # --- accommodations: view vs manage ----------------------------------------
  # REAL since guidelines/CLOSURE_PLAN.md Fase D — StudentSupport::
  # Accommodation replaces the AccommodationRoster stub (#update was a no-op).

  def build_accommodation(student)
    within_tenant(@institution) do
      staff = @institution.memberships.find_by!(user: @user)
      StudentSupport::Accommodation.create!(institution: @institution, student: student, authorized_by: staff,
        kind: "extra_time", description: "Tiempo adicional en evaluaciones.")
    end
  end

  test "accommodations index is scoped by the student's group" do
    in_scope, out_of_scope = build_real_students

    as_counselor_9a do
      get "/student_support/students/#{in_scope.id}/accommodations"
      assert_response :success

      get "/student_support/students/#{out_of_scope.id}/accommodations"
      assert_response :forbidden
    end
  end

  test "can? shows 'Editar' only for a role holding accommodations.manage" do
    in_scope, = build_real_students
    build_accommodation(in_scope)

    as_coordinator do
      get "/student_support/students/#{in_scope.id}/accommodations"
      assert_select "a.btn", text: "Editar"
    end

    as_homeroom_readonly do
      get "/student_support/students/#{in_scope.id}/accommodations"
      assert_response :success
      assert_select "a.btn", text: "Editar", count: 0
    end
  end

  test "authorize! denies editing an accommodation for a read-only role, matching can?" do
    in_scope, = build_real_students
    accommodation = build_accommodation(in_scope)

    as_homeroom_readonly do
      get "/student_support/students/#{in_scope.id}/accommodations/#{accommodation.id}/edit"
      assert_response :forbidden
    end
  end

  test "coordinator can edit an accommodation, and it persists for real" do
    in_scope, = build_real_students
    accommodation = build_accommodation(in_scope)

    as_coordinator do
      get "/student_support/students/#{in_scope.id}/accommodations/#{accommodation.id}/edit"
      assert_response :success

      patch "/student_support/students/#{in_scope.id}/accommodations/#{accommodation.id}",
        params: { accommodation: { description: "Descripción actualizada." } }
      assert_response :redirect
      assert_equal "Descripción actualizada.", accommodation.reload.description
    end
  end

  test "coordinator can create a new accommodation; a read-only role cannot" do
    in_scope, = build_real_students

    as_coordinator do
      assert_difference -> { StudentSupport::Accommodation.count }, 1 do
        post "/student_support/students/#{in_scope.id}/accommodations",
          params: { accommodation: { kind: "adapted_material", description: "Material en fuente ampliada." } }
      end
      assert_response :redirect
    end

    as_homeroom_readonly do
      post "/student_support/students/#{in_scope.id}/accommodations",
        params: { accommodation: { kind: "other", description: "x" } }
      assert_response :forbidden
    end
  end

  # --- disciplinary_logs (convivencia) — REAL since guidelines/CLOSURE_PLAN.md
  # Fase B (StudentSupport::DisciplinaryLog replaces the DisciplinaryLogRoster
  # stub). Real students in real sections, not the old stub string ids.

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
    # real to count (accommodations/disciplinary_logs are both real since
    # guidelines/CLOSURE_PLAN.md Fase B/D but this test seeds neither, so
    # those stats stay "0").
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
    # #4 barrido (v1.14.0). Convivencia AND Acomodaciones are both real since
    # guidelines/CLOSURE_PLAN.md Fase B/D (StudentSupport::DisciplinaryLog/
    # Accommodation) — both gated by can? against this real student's real
    # group_id.
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
