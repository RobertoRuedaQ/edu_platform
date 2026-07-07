require "test_helper"

class GroupManagementTest < ActionDispatch::IntegrationTest
  # Same technique as TeacherManagementTest: install a custom
  # Authorization::StubAssignments persona for the block, independent of the
  # shared default demo persona.
  def with_grants(*assignments)
    original = Authorization::StubAssignments.method(:all)
    Authorization::StubAssignments.define_singleton_method(:all) { assignments }
    yield
  ensure
    Authorization::StubAssignments.define_singleton_method(:all, original)
  end

  # homeroom teacher of 9°A only.
  def as_homeroom(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom",
                                     permission_keys: %w[students.read groups.view groups.manage],
                                     scope_type: :group, scope_id: "stub-section-9a"),
      &block
    )
  end

  # secretary: institution-wide read on students/groups, no groups.manage.
  def as_secretary(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "secretary",
                                     permission_keys: %w[students.read groups.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "students index filters to the actor's own group, not the whole institution" do
    as_homeroom do
      get "/group_management/students"
      assert_response :success

      assert_select "a.student-row__person", text: /Valentina Suárez/
      assert_select "a.student-row__person", text: /Santiago Rojas/
      assert_select "a.student-row__person", text: /Mateo Cárdenas/, count: 0
      assert_select "a.student-row__person", text: /Daniela Ortiz/, count: 0
    end
  end

  test "students index for an institution-wide read role sees every student" do
    as_secretary do
      get "/group_management/students"
      assert_response :success
      assert_select ".table tbody tr", count: GroupManagement::StudentRoster.all.size
    end
  end

  test "an actor with no grants is denied the students index (403)" do
    with_grants do
      get "/group_management/students"
      assert_response :forbidden
    end
  end

  test "homeroom can view a student inside their own group but not one outside it" do
    as_homeroom do
      get "/group_management/students/s-1"
      assert_response :success

      get "/group_management/students/s-4"
      assert_response :forbidden
    end
  end

  test "groups index and show are scoped the same way" do
    as_homeroom do
      get "/group_management/groups"
      assert_response :success
      assert_select "a", text: "9°A"
      assert_select "a", text: "10°A", count: 0

      get "/group_management/groups/stub-section-9a"
      assert_response :success

      get "/group_management/groups/stub-section-10a"
      assert_response :forbidden
    end
  end

  test "can? shows 'Editar matrícula' only for a role holding groups.manage" do
    as_homeroom do
      get "/group_management/groups/stub-section-9a"
      assert_select "a.btn", text: "Editar matrícula"
    end

    as_secretary do
      get "/group_management/groups/stub-section-9a"
      assert_response :success
      assert_select "a.btn", text: "Editar matrícula", count: 0
    end
  end

  test "authorize! denies the membership edit form for a role without groups.manage, matching can?" do
    as_secretary do
      get "/group_management/groups/stub-section-9a/membership/edit"
      assert_response :forbidden
    end
  end

  test "homeroom can open the membership edit form for their own group" do
    as_homeroom do
      get "/group_management/groups/stub-section-9a/membership/edit"
      assert_response :success
      assert_select "input[type=checkbox][name='student_ids[]']", minimum: 1
    end
  end
end
