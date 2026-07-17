require "test_helper"

class ControlPlane::EntitlementsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)

    @institution = Core::Institution.create!(name: "Colegio Entitlements", slug: "colegio-ent",
      code: "ENT-1", kind: "school")
    @addon = ControlPlane::Addon.create!(key: "cafeteria", name: "Cafetería", currency: "COP")
  end

  test "granting an addon creates an active entitlement and audits it" do
    post control_plane_entitlements_path(institution_id: @institution.id), params: {
      entitlement: { addon_id: @addon.id, valid_from: Date.current }
    }

    entitlement = ControlPlane::Entitlement.find_by(institution_id: @institution.id, addon_id: @addon.id)
    assert entitlement.present?
    assert entitlement.active?
    assert ControlPlane::AuditEvent.exists?(action: "entitlement.granted", target_id: entitlement.id)
  end

  test "granting a second active entitlement for the same addon is rejected" do
    ControlPlane::Entitlement.create!(institution: @institution, addon: @addon, valid_from: Date.current)

    post control_plane_entitlements_path(institution_id: @institution.id), params: {
      entitlement: { addon_id: @addon.id, valid_from: Date.current }
    }

    assert_equal 1, ControlPlane::Entitlement.active.where(institution_id: @institution.id, addon_id: @addon.id).count
  end

  test "revoking and reactivating an entitlement is soft and audited" do
    entitlement = ControlPlane::Entitlement.create!(institution: @institution, addon: @addon, valid_from: 1.day.ago.to_date)

    patch revoke_control_plane_entitlement_path(entitlement)
    assert_equal "revoked", entitlement.reload.status
    assert ControlPlane::AuditEvent.exists?(action: "entitlement.revoked", target_id: entitlement.id)

    patch reactivate_control_plane_entitlement_path(entitlement)
    assert_equal "active", entitlement.reload.status
    assert ControlPlane::AuditEvent.exists?(action: "entitlement.reactivated", target_id: entitlement.id)
  end

  test "updating fechado and overrides persists them without affecting entitled?" do
    entitlement = ControlPlane::Entitlement.create!(institution: @institution, addon: @addon, valid_from: Date.current)

    patch control_plane_entitlement_path(entitlement), params: {
      entitlement: { override_monthly_fee_cents: 650_000, override_included_quota: 30_000, override_currency: "COP" }
    }

    entitlement.reload
    assert_equal 650_000, entitlement.override_monthly_fee_cents
    assert ControlPlane::AuditEvent.exists?(action: "entitlement.updated", target_id: entitlement.id)
    assert ControlPlane::Entitlements::Check.entitled?(institution: @institution, addon_key: @addon.key)
  end
end
