require "test_helper"

# #4 slice 1 — teacher_management as the CANONICAL reference for the
# "business view" pattern (PROJECT_STATE.md §6.6): index-with-scope -> show ->
# per-row-gated action. This is supervision (RBAC + scope), the opposite of
# the identity-gated self-service (`/mis_datos`, v1.10.0) — every action here
# goes through authorize!.
class TeacherManagementTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_department!(institution, name:, code:, kind: "academic")
    StaffManagement::Department.create!(institution: institution, name: name, code: code, kind: kind)
  end

  # A real Teacher, linked to a real StaffMember (D1), optionally placed in a
  # department. Mirrors the identical seeding shape self_service_test.rb
  # already uses for the same tables.
  def build_teacher!(institution, first_name:, last_name:, teacher_code:, department: nil, email:)
    user = Core::User.create!(email: email, name: "#{first_name} #{last_name}")
    iu = institution.memberships.create!(user: user)
    staff_member = StaffManagement::StaffMember.create!(institution: institution, institution_user: iu,
      employee_number: "EMP-#{teacher_code}", staff_category: "teaching", employment_type: "full_time",
      department: department)
    TeacherManagement::Teacher.create!(institution: institution, staff_member: staff_member,
      first_name: first_name, last_name: last_name, gender: "female", teacher_code: teacher_code)
  end

  setup do
    @user, @institution = sign_in_as_member

    @matematicas = within_tenant(@institution) { build_department!(@institution, name: "Matemáticas", code: "MAT") }
    @sociales    = within_tenant(@institution) { build_department!(@institution, name: "Ciencias Sociales", code: "SOC") }

    @maria_colleague = within_tenant(@institution) do
      build_teacher!(@institution, first_name: "Carlos Andrés", last_name: "Peña", teacher_code: "T-002",
        department: @matematicas, email: "carlos@correo.test")
    end
    @outside_teacher = within_tenant(@institution) do
      build_teacher!(@institution, first_name: "Laura", last_name: "Gómez Duarte", teacher_code: "T-003",
        department: @sociales, email: "laura@correo.test")
    end
  end

  # María: teacher over her own two groups (unrelated to this slice's scope —
  # group_management is still stub, a later #4 slice), AND area_lead over
  # Matemáticas — the P1 acceptance persona (§6.4), now exercised against
  # REAL Teacher/Department rows instead of the retired in-memory rosters.
  def as_maria(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[schedule.view],
                                     scope_type: :group, scope_id: GroupManagement::GroupRoster::SECTION_10A_ID),
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[schedule.view],
                                     scope_type: :group, scope_id: GroupManagement::GroupRoster::SECTION_11B_ID),
      Authorization::Assignment.new(role_key: "area_lead",
                                     permission_keys: %w[teachers.view teacher.evaluate departments.view staff.read],
                                     scope_type: :department, scope_id: @matematicas.id),
      &block
    )
  end

  # secretary: institution-wide READ on teachers/departments, but no
  # teacher.evaluate at all — exercises can? hiding an action authorize! would
  # also deny, for a role distinct from area_lead's own scope.
  def as_secretary(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "secretary",
                                     permission_keys: %w[teachers.view departments.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # A plain teacher: teachers.view scoped to their OWN group (same scope as
  # their teaching duty) — no area_lead, no department-wide grant. They pass
  # the blanket authorize!("teachers.view") gate (a capability check with no
  # resource always passes on scope — scoping a LIST is the query object's
  # job), but the per-row can? filter then excludes every real Teacher row,
  # since a Teacher never responds to :group_id (no real teacher<->group
  # link exists anywhere in the schema) — so the index resolves empty, not
  # denied outright. Supervises nobody, correctly.
  def as_plain_teacher(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[schedule.view teachers.view],
                                     scope_type: :group, scope_id: GroupManagement::GroupRoster::SECTION_10A_ID),
      &block
    )
  end

  test "index filters to the actor's scope, not the whole institution" do
    as_maria do
      get "/teacher_management/teachers"
      assert_response :success

      assert_select "a.teacher-row__person", text: /Carlos Andrés Peña/
      assert_select "a.teacher-row__person", text: /Laura Gómez Duarte/, count: 0
    end
  end

  test "index for an institution-wide read role sees every teacher" do
    as_secretary do
      get "/teacher_management/teachers"
      assert_response :success
      assert_select ".table tbody tr", count: 2
    end
  end

  test "an actor with no grants at all is denied the index (403), not an empty table" do
    with_grants do
      get "/teacher_management/teachers"
      assert_response :forbidden
    end
  end

  # Acceptance case §5: a teacher with no area_lead grant supervises nobody —
  # an empty/self-only index, never a 500, never someone else's data.
  test "a teacher with no area_lead grant sees an empty supervision index, not an error" do
    as_plain_teacher do
      get "/teacher_management/teachers"
      assert_response :success
      assert_select ".table tbody tr", count: 0
      assert_select ".empty-state__title"
    end
  end

  # --- Acceptance case (María, §6.4/§5) --------------------------------------

  test "acceptance: area_lead can evaluate a teacher inside their own department" do
    as_maria do
      get "/teacher_management/teachers/#{@maria_colleague.id}/evaluations/new"
      assert_response :success
    end
  end

  test "acceptance: area_lead is denied evaluating a teacher outside their department" do
    as_maria do
      get "/teacher_management/teachers/#{@outside_teacher.id}/evaluations/new"
      assert_response :forbidden
    end
  end

  test "acceptance: area_lead cannot even view a teacher outside their department" do
    as_maria do
      get "/teacher_management/teachers/#{@outside_teacher.id}"
      assert_response :forbidden
    end
  end

  test "can? shows the evaluate action only where authorize! would also allow it" do
    as_maria do
      get "/teacher_management/teachers/#{@maria_colleague.id}"
      assert_response :success
      assert_select "a.btn", text: "Nueva evaluación"
    end
  end

  test "can? hides the evaluate action for a role that can view but never evaluate" do
    as_secretary do
      get "/teacher_management/teachers/#{@maria_colleague.id}"
      assert_response :success
      assert_select "a.btn", text: "Nueva evaluación", count: 0
    end
  end

  test "authorize! denies the evaluation form for a view-only role, matching can?" do
    as_secretary do
      get "/teacher_management/teachers/#{@maria_colleague.id}/evaluations/new"
      assert_response :forbidden
    end
  end

  test "departments index and show are scoped the same way as teachers" do
    as_maria do
      get "/teacher_management/departments"
      assert_response :success
      assert_select "a", text: "Matemáticas"
      assert_select "a", text: "Ciencias Sociales", count: 0

      get "/teacher_management/departments/#{@matematicas.id}"
      assert_response :success
      assert_select ".teacher-row__person", text: /Carlos Andrés Peña/

      get "/teacher_management/departments/#{@sociales.id}"
      assert_response :forbidden
    end
  end

  test "cross-tenant: a teacher/department seeded in a different institution never leaks into this one's index" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "tm-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(other_institution) do
      dept = build_department!(other_institution, name: "Matemáticas Otro Colegio", code: "MAT")
      build_teacher!(other_institution, first_name: "Fantasma", last_name: "Cruzado", teacher_code: "T-999",
        department: dept, email: "ghost@correo.test")
    end

    as_secretary do
      get "/teacher_management/teachers"
      assert_response :success
      assert_no_match(/Fantasma Cruzado/, response.body)
      assert_select ".table tbody tr", count: 2

      get "/teacher_management/departments"
      assert_response :success
      assert_no_match(/Matemáticas Otro Colegio/, response.body)
    end
  end
end
