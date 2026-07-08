require "test_helper"

class ControlPlane::AddonsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)
  end

  test "creates a non-metered addon and audits it" do
    post control_plane_addons_path, params: { addon: {
      key: "cafeteria", name: "Cafetería", monthly_fee_cents: 500_000, currency: "COP", metered: "0"
    } }

    addon = ControlPlane::Addon.find_by(key: "cafeteria")
    assert addon.present?
    assert_not addon.metered?
    assert_nil addon.included_quota
    assert ControlPlane::AuditEvent.exists?(action: "addon.created", target_id: addon.id)
  end

  test "rejects a key that is not an addon-able domain" do
    post control_plane_addons_path, params: { addon: {
      key: "core", name: "Núcleo", monthly_fee_cents: 0, currency: "COP", metered: "0"
    } }

    assert_not ControlPlane::Addon.exists?(key: "core")
    assert_response :unprocessable_entity
  end

  test "rejects a metered addon missing quota/unit/overage price" do
    post control_plane_addons_path, params: { addon: {
      key: "transportation", name: "Transporte", currency: "COP", metered: "1"
    } }

    assert_not ControlPlane::Addon.exists?(key: "transportation")
    assert_response :unprocessable_entity
  end

  test "creates a metered addon with all metering fields present" do
    post control_plane_addons_path, params: { addon: {
      key: "transportation", name: "Transporte", currency: "COP", metered: "1",
      included_quota: 5_000, unit: "check-ins", overage_unit_price_cents: 50
    } }

    addon = ControlPlane::Addon.find_by(key: "transportation")
    assert addon.present?
    assert addon.metered?
    assert_equal 5_000, addon.included_quota
    assert ControlPlane::AuditEvent.exists?(action: "addon.created", target_id: addon.id)
  end

  test "retiring and reactivating an addon is soft and audited" do
    addon = ControlPlane::Addon.create!(key: "finance", name: "Tesorería", monthly_fee_cents: 0, currency: "COP")

    patch retire_control_plane_addon_path(addon)
    assert_equal "retired", addon.reload.status
    assert ControlPlane::AuditEvent.exists?(action: "addon.retired", target_id: addon.id)
    assert ControlPlane::Addon.exists?(id: addon.id) # never destroyed

    patch reactivate_control_plane_addon_path(addon)
    assert_equal "active", addon.reload.status
    assert ControlPlane::AuditEvent.exists?(action: "addon.reactivated", target_id: addon.id)
  end

  test "a tenant Core::User cannot reach the addon catalog" do
    delete control_plane_session_path # sign the platform admin out first

    tenant_password = "tenant-password-123456"
    institution = Core::Institution.create!(name: "Colegio Addons", slug: "colegio-addons",
      code: "CA-2", kind: "school")
    user = Core::User.create!(email: "profe@colegio-addons.test", name: "Profe", password: tenant_password)
    within_tenant(institution) { institution.memberships.create!(user: user) }
    sign_in_as(user, institution: institution, password: tenant_password)

    get control_plane_addons_path
    assert_redirected_to new_control_plane_session_path
  end

  private

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end
end
