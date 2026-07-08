require "test_helper"

class ShellNavigationTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_member } # auth is now required app-wide; persona still from StubAssignments

  # Uses the default Authorization::StubAssignments persona (group director +
  # area head): grants students/grades/staff/counseling reads, but NOT
  # finance.read nor roles.manage. So the role-aware nav must omit those two.

  test "search page renders the role-aware shell with only permitted nav items" do
    get "/search"
    assert_response :success

    assert_select "nav.app-nav" do
      assert_select "a.app-nav__link", text: "Estudiantes"
      assert_select "a.app-nav__link", text: "Calificaciones"
      assert_select "a.app-nav__link", text: "Personal"
      assert_select "a.app-nav__link", text: "Orientación"
    end

    # Absent (not disabled) for permissions the actor lacks.
    assert_select "a.app-nav__link", text: "Cartera", count: 0
    assert_select "a.app-nav__link", text: "Roles y accesos", count: 0
  end

  test "global search results are a stub empty state" do
    get "/search", params: { q: "juan" }
    assert_response :success
    assert_select ".empty-state__title", text: "Búsqueda pendiente"
  end

  test "institution switcher renders for a multi-institution actor" do
    # FLAGGED: this asserted the OLD hardcoded stub CurrentActor (two fake
    # institutions). CurrentActor now wraps the real Current.user/institution,
    # and a normal RLS runtime connection can only ever see the CURRENT tenant's
    # membership — so a cross-tenant "multi-institution" switcher can't be built
    # from a plain request. Needs a product decision (defer switcher, or a
    # sanctioned bypass-RLS lookup). Skipped pending that decision.
    skip "multi-institution switcher deferred: real CurrentActor + RLS expose only the current tenant"

    get "/search"
    assert_select "form.role-switcher__form select[name=institution_id]"
    assert_select "option", text: "Colegio San Martín"
    assert_select "option", text: "Instituto Andes"
  end
end
