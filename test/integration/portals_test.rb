require "test_helper"

class PortalsTest < ActionDispatch::IntegrationTest
  # Person portals are resolved by relation, not by role_assignments, so they
  # render the same regardless of the actor's Authorization::StubAssignments
  # persona — there is no authorize! gate on either action.

  test "student portal renders the student's own shortcuts, not the staff shell" do
    get "/portal/student"
    assert_response :success

    assert_select ".tile-grid" do
      assert_select "a.tile", text: /Mi horario/
      assert_select "a.tile", text: /Mis grupos/
      assert_select "a.tile", text: /Cafetería/
      assert_select "a.tile", text: /Transporte/
    end

    # A separate, minimal person surface — no staff domain nav or global search.
    assert_select "nav.app-nav", count: 0
    assert_select ".app-search", count: 0
  end

  test "guardian portal renders a tab panel per child with that child's shortcuts" do
    get "/portal/guardian"
    assert_response :success

    assert_select ".tabs__tab", text: "Ana Martínez"
    assert_select ".tabs__tab", text: "Luis Martínez"

    assert_select ".tabs__panel", text: /9°A/
    assert_select ".tabs__panel", text: /6°B/

    assert_select "nav.app-nav", count: 0
  end
end
