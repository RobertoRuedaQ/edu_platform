require "test_helper"

class AnalyticsBiTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_member } # auth is now required app-wide; persona still from StubAssignments
  def with_grants(*assignments)
    original = Authorization::StubAssignments.method(:all)
    Authorization::StubAssignments.define_singleton_method(:all) { assignments }
    yield
  ensure
    Authorization::StubAssignments.define_singleton_method(:all, original)
  end

  def as_principal(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "principal", permission_keys: %w[institution_dashboard.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_bi_auditor(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "bi_auditor", permission_keys: %w[cross_tenant_reports.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "institution dashboard requires institution_dashboard.view" do
    with_grants { get "/analytics_bi/dashboard"; assert_response :forbidden }

    as_principal do
      get "/analytics_bi/dashboard"
      assert_response :success
      assert_select ".stat__value", text: "187"
    end
  end

  test "cross_tenant_reports requires cross_tenant_reports.view" do
    with_grants { get "/analytics_bi/cross_tenant_reports"; assert_response :forbidden }

    as_bi_auditor do
      get "/analytics_bi/cross_tenant_reports"
      assert_response :success
      assert_select ".alert__title", text: "Modo auditoría"
      assert_select "td", text: "Universidad Andina"
    end
  end

  # --- the security invariant Apéndice A calls out explicitly ---------------

  test "institution_dashboard.view never implies cross_tenant_reports.view" do
    as_principal do
      get "/analytics_bi/cross_tenant_reports"
      assert_response :forbidden
    end
  end

  test "cross_tenant_reports.view never implies institution_dashboard.view" do
    as_bi_auditor do
      get "/analytics_bi/dashboard"
      assert_response :forbidden
    end
  end

  test "the default demo persona holds neither analytics permission" do
    get "/analytics_bi/dashboard"
    assert_response :forbidden

    get "/analytics_bi/cross_tenant_reports"
    assert_response :forbidden
  end

  test "the default demo persona's dashboard nav never shows Analítica or Auditoría BI" do
    get "/"
    assert_response :success
    assert_select "a.tile", text: /Analítica/, count: 0
    assert_select "a.tile", text: /Auditoría BI/, count: 0
  end
end
