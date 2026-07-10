require "test_helper"

# Baseline portal behavior for a generic signed-in member with NO
# student/guardian relation at all (sign_in_as_member's default actor) —
# GS9's empty-state guarantee. The full security acceptance case (cross-
# tenant isolation, revoked links, per-child URL boundaries, no-search) lives
# in test/integration/guardian_scope_test.rb, which seeds the real relations
# this file deliberately doesn't have.
class PortalsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_member } # portals have no authorize! gate — resolved by relation, not RBAC

  test "student portal renders an empty state for an actor with no linked student record" do
    get "/portal/student"
    assert_response :success

    assert_select ".empty-state__title"
    # A separate, minimal person surface — no staff domain nav or global search.
    assert_select "nav.app-nav", count: 0
    assert_select ".app-search", count: 0
  end

  test "guardian portal renders an empty state for an actor with no active guardian links" do
    get "/portal/guardian"
    assert_response :success

    assert_select ".empty-state__title"
    assert_select "nav.app-nav", count: 0
  end
end
