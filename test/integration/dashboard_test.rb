require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  # Default Authorization::StubAssignments persona grants students/grades/staff/
  # counseling reads, but NOT finance.read nor roles.manage.

  test "root renders role-aware shortcut tiles for permitted domains only" do
    get "/"
    assert_response :success

    assert_select ".tile-grid" do
      assert_select "a.tile", text: /Estudiantes/
      assert_select "a.tile", text: /Calificaciones/
      assert_select "a.tile", text: /Personal/
      assert_select "a.tile", text: /Orientación/
    end

    assert_select "a.tile", text: /Cartera/, count: 0
    assert_select "a.tile", text: /Roles y accesos/, count: 0
  end

  test "tiles link to their domain index (clic 1)" do
    get "/"
    assert_select "a.tile[href='/group_management/students']"
  end

  test "a tile shows its stub metric" do
    get "/"
    assert_select ".tile", text: /128/
  end

  test "shows a clear empty state when the actor has no accesses" do
    original = Authorization::StubAssignments.method(:all)
    Authorization::StubAssignments.define_singleton_method(:all) { [] }

    get "/"
    assert_response :success
    assert_select ".empty-state__title", text: "Aún no tienes accesos asignados"
    assert_select ".tile-grid", count: 0
  ensure
    Authorization::StubAssignments.define_singleton_method(:all, original)
  end
end
