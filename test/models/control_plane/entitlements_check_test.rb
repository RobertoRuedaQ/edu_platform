require "test_helper"

class ControlPlane::EntitlementsCheckTest < ActiveSupport::TestCase
  def build_institution
    slug = "chk-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_addon(key: "cafeteria")
    ControlPlane::Addon.create!(key: key, name: "Addon de prueba", currency: "COP")
  end

  test "true for an active entitlement within its fechado" do
    institution = build_institution
    addon = build_addon
    ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current)

    assert ControlPlane::Entitlements::Check.entitled?(institution: institution, addon_key: addon.key)
  end

  test "false before valid_from" do
    institution = build_institution
    addon = build_addon
    ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current + 5)

    assert_not ControlPlane::Entitlements::Check.entitled?(institution: institution, addon_key: addon.key)
  end

  test "false after valid_until" do
    institution = build_institution
    addon = build_addon
    ControlPlane::Entitlement.create!(institution: institution, addon: addon,
      valid_from: Date.current - 10, valid_until: Date.current - 1)

    assert_not ControlPlane::Entitlements::Check.entitled?(institution: institution, addon_key: addon.key)
  end

  test "false once revoked" do
    institution = build_institution
    addon = build_addon
    entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: 1.day.ago.to_date)
    entitlement.revoke!

    assert_not ControlPlane::Entitlements::Check.entitled?(institution: institution, addon_key: addon.key)
  end

  test "false for an addon never granted to this institution" do
    institution = build_institution
    build_addon(key: "cafeteria")

    assert_not ControlPlane::Entitlements::Check.entitled?(institution: institution, addon_key: "cafeteria")
  end

  test "false for an unknown addon_key" do
    institution = build_institution

    assert_not ControlPlane::Entitlements::Check.entitled?(institution: institution, addon_key: "does_not_exist")
  end

  test "overrides do not affect the boolean" do
    institution = build_institution
    addon = build_addon
    ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current,
      override_monthly_fee_cents: 999_999, override_included_quota: 1, override_currency: "COP")

    assert ControlPlane::Entitlements::Check.entitled?(institution: institution, addon_key: addon.key)
  end
end
