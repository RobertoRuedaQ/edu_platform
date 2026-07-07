require "test_helper"

class TeacherManagementTest < ActionDispatch::IntegrationTest
  # Installs a custom Authorization::StubAssignments persona for the duration
  # of the block, same technique as DashboardTest's empty-state test — so each
  # scenario is independent of the shared default demo persona.
  def with_grants(*assignments)
    original = Authorization::StubAssignments.method(:all)
    Authorization::StubAssignments.define_singleton_method(:all) { assignments }
    yield
  ensure
    Authorization::StubAssignments.define_singleton_method(:all, original)
  end

  # María: teacher over her own two groups, AND area_lead over Matemáticas.
  # This is the Apéndice A acceptance persona.
  def as_maria(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[schedule.view],
                                     scope_type: :group, scope_id: "stub-section-10a"),
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[schedule.view],
                                     scope_type: :group, scope_id: "stub-section-11b"),
      Authorization::Assignment.new(role_key: "area_lead",
                                     permission_keys: %w[teachers.view teacher.evaluate departments.view],
                                     scope_type: :department, scope_id: "dept-matematicas"),
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

  test "index filters to the actor's scope, not the whole institution" do
    as_maria do
      get "/teacher_management/teachers"
      assert_response :success

      assert_select "a.teacher-row__person", text: /María Fernanda Ríos/
      assert_select "a.teacher-row__person", text: /Carlos Andrés Peña/
      assert_select "a.teacher-row__person", text: /Laura Gómez Duarte/, count: 0
      assert_select "a.teacher-row__person", text: /Jorge Iván Salas/, count: 0
      assert_select "a.teacher-row__person", text: /Ana Sofía Beltrán/, count: 0
    end
  end

  test "index for an institution-wide read role sees every teacher" do
    as_secretary do
      get "/teacher_management/teachers"
      assert_response :success
      assert_select ".table tbody tr", count: TeacherManagement::TeacherRoster.all.size
    end
  end

  test "an actor with no grants at all is denied the index (403), not an empty table" do
    with_grants do
      get "/teacher_management/teachers"
      assert_response :forbidden
    end
  end

  # --- Acceptance case (Apéndice A: teacher_management) ---------------------

  test "acceptance: area_lead can evaluate a teacher inside their own department" do
    as_maria do
      get "/teacher_management/teachers/t-1/evaluations/new"
      assert_response :success
    end
  end

  test "acceptance: area_lead is denied evaluating a teacher outside their department" do
    as_maria do
      get "/teacher_management/teachers/t-3/evaluations/new"
      assert_response :forbidden
    end
  end

  test "acceptance: area_lead cannot even view a teacher outside their department" do
    as_maria do
      get "/teacher_management/teachers/t-3"
      assert_response :forbidden
    end
  end

  test "can? shows the evaluate action only where authorize! would also allow it" do
    as_maria do
      get "/teacher_management/teachers/t-1"
      assert_response :success
      assert_select "a.btn", text: "Nueva evaluación"
    end
  end

  test "can? hides the evaluate action for a role that can view but never evaluate" do
    as_secretary do
      get "/teacher_management/teachers/t-1"
      assert_response :success
      assert_select "a.btn", text: "Nueva evaluación", count: 0
    end
  end

  test "authorize! denies the evaluation form for a view-only role, matching can?" do
    as_secretary do
      get "/teacher_management/teachers/t-1/evaluations/new"
      assert_response :forbidden
    end
  end

  test "departments index and show are scoped the same way as teachers" do
    as_maria do
      get "/teacher_management/departments"
      assert_response :success
      assert_select "a", text: "Matemáticas"
      assert_select "a", text: "Ciencias Sociales", count: 0

      get "/teacher_management/departments/dept-matematicas"
      assert_response :success

      get "/teacher_management/departments/dept-sociales"
      assert_response :forbidden
    end
  end
end
