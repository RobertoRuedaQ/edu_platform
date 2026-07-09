require "test_helper"

# Cross-domain acceptance test for S2b: the entitlement gate (§7.1's first
# serial gate) wired into the tenant shell. "Colegio Demo" has cafeteria
# entitled and transportation NOT entitled; teacher_management is
# foundational and never gated at all.
class EntitlementGateTest < ActionDispatch::IntegrationTest
  def with_grants(*assignments)
    original = Authorization::StubAssignments.method(:all)
    Authorization::StubAssignments.define_singleton_method(:all) { assignments }
    yield
  ensure
    Authorization::StubAssignments.define_singleton_method(:all, original)
  end

  # Covers both gated domains AND the foundational one, so every test below
  # isolates the entitlement gate — RBAC would say yes to all of these.
  def as_full_access(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "test_actor",
        permission_keys: %w[menu.view checkout.manage routes.view boarding.manage teachers.view],
        scope_type: :institution, scope_id: nil),
      &block
    )
  end

  setup do
    # sign_in_as_member grants every gated domain by default (see
    # test_helper.rb) — revoke transportation specifically to get the
    # "not entitled" half of this test's scenario; cafeteria stays granted.
    @user, @institution = sign_in_as_member

    @cafeteria_entitlement = ControlPlane::Entitlement.joins(:addon)
      .find_by!(institution_id: @institution.id, addons: { key: "cafeteria" })
    @transportation_entitlement = ControlPlane::Entitlement.joins(:addon)
      .find_by!(institution_id: @institution.id, addons: { key: "transportation" })
    @transportation_entitlement.revoke!
  end

  test "habilitado: cafeteria is reachable and its nav tile appears" do
    as_full_access do
      get "/cafeteria/menu"
      assert_response :success
      assert_select ".app-nav__link", text: "Cafetería"
    end
  end

  test "no habilitado: transportation is blocked with the friendly module page, tile absent" do
    as_full_access do
      get "/transportation/routes"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
      assert_select ".app-nav__link", text: "Rutas", count: 0
    end
  end

  test "fundacional: teacher_management is accessible without any entitlement, tile present" do
    as_full_access do
      get "/teacher_management/teachers"
      assert_response :success
      assert_select ".app-nav__link", text: "Docentes"
    end
  end

  test "direct URL access to a write action of a non-entitled domain is blocked too" do
    as_full_access do
      post "/transportation/boarding_events", params: { route_id: "route-1", student_id: "s-1", status_label: "abordaje" }
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "gate order: entitlement wins over RBAC — no grants at all still yields the entitlement page" do
    with_grants do # zero grants: RBAC would deny too, on its own
      get "/transportation/routes"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
      assert_no_match(/No tienes acceso a esta sección/, response.body)
    end
  end

  test "revoking the entitlement blocks the very next request and hides the tile" do
    as_full_access do
      get "/cafeteria/menu"
      assert_response :success

      @cafeteria_entitlement.revoke!

      get "/cafeteria/menu"
      assert_response :forbidden
      assert_match "no está habilitado", response.body

      get "/teacher_management/teachers"
      assert_select ".app-nav__link", text: "Cafetería", count: 0
    end
  end

  test "fail-closed: no institution resolved denies the gated domain" do
    # Authenticated (valid session, Authentication passes) but the tenant
    # resolver comes up empty for THIS request — e.g. the institution's
    # subdomain briefly fails to resolve. Using the resolver's own test seam
    # instead of a host swap, which would conflate "no institution" with "no
    # session" (the cookie wouldn't follow to a different host anyway).
    #
    # Only asserts the GATED half here: rendering a full successful shell
    # page with no Current.institution hits a pre-existing, unrelated shell
    # assumption (shared/_role_switcher expects one) that no real browser
    # flow can reach (a session cookie never follows to a host with no
    # matching institution) — not something S2b's minimal, uniform touch
    # should go fix. "Foundational is unaffected either way" is covered by
    # combining the "fundacional" test above (accessible when gated? is
    # false, institution present) with the registry consistency test (no
    # foundational domain is ever declared gated) and the unit test below
    # (EntitledAddonKeys.for(nil) is empty) — together they cover the same
    # ground without this one impossible-in-practice combination.
    original_strategy = Tenant::Resolver.strategy
    Tenant::Resolver.strategy = ->(_request) { nil }

    as_full_access do
      get "/cafeteria/menu"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  ensure
    Tenant::Resolver.strategy = original_strategy
  end
end
