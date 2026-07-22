require "test_helper"

class ControlPlane::EntitlementTest < ActiveSupport::TestCase
  def build_institution
    slug = "ent-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_addon(key: "cafeteria")
    ControlPlane::Addon.create!(key: key, name: "Addon de prueba", currency: "COP")
  end

  test "grant!/revoke!/reactivate! never destroy the row" do
    institution = build_institution
    addon = build_addon
    # valid_from in the past: revoke! closes valid_until at Date.current,
    # which is invalid when equal to valid_from (same restriction as
    # Subscription#end!) — see the dedicated same-day test below.
    entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: 1.day.ago.to_date)

    entitlement.revoke!
    assert_equal "revoked", entitlement.reload.status
    assert ControlPlane::Entitlement.exists?(id: entitlement.id)

    entitlement.reactivate!
    assert_equal "active", entitlement.reload.status
  end

  test "only one active entitlement per institution+addon" do
    institution = build_institution
    addon = build_addon
    ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current)

    duplicate = ControlPlane::Entitlement.new(institution: institution, addon: addon, valid_from: Date.current)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:base].join, "ya existe un entitlement activo"
  end

  test "revoking one entitlement allows granting a fresh one for the same addon" do
    institution = build_institution
    addon = build_addon
    # valid_from in the past: revoke! closes valid_until at Date.current (same
    # restriction as Subscription#end! — same-day revoke is invalid, see the
    # dedicated test below), so the grant can't have started today too.
    first = ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: 1.day.ago.to_date)
    first.revoke!
    assert_equal Date.current, first.reload.valid_until

    second = ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current)
    assert second.active?
  end

  test "revoke! closes valid_until (never leaves it open-ended), and reactivate! reopens it" do
    institution = build_institution
    addon = build_addon
    entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: 1.day.ago.to_date)

    entitlement.revoke!
    assert_equal Date.current, entitlement.reload.valid_until

    entitlement.reactivate!
    assert_nil entitlement.reload.valid_until
  end

  test "revoking the same day it was granted is invalid (mirrors Subscription#end!'s same-day restriction)" do
    institution = build_institution
    addon = build_addon
    entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current)

    assert_raises(ActiveRecord::RecordInvalid) { entitlement.revoke! }
  end

  test "a new grant's range can never overlap a past (revoked) one for the same institution+addon — DB-enforced" do
    institution = build_institution
    addon = build_addon
    first = ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: 10.days.ago.to_date)
    first.revoke!(valid_until: 5.days.ago.to_date)

    assert_raises(ActiveRecord::StatementInvalid) do
      ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: 7.days.ago.to_date)
    end
  end

  test "valid_until must be after valid_from" do
    institution = build_institution
    addon = build_addon
    entitlement = ControlPlane::Entitlement.new(institution: institution, addon: addon,
      valid_from: Date.current, valid_until: Date.current)

    assert_not entitlement.valid?
    assert_includes entitlement.errors[:valid_until].join, "posterior"
  end

  test "active_on? respects the fechado" do
    institution = build_institution
    addon = build_addon
    entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: addon,
      valid_from: Date.current, valid_until: Date.current + 10)

    assert entitlement.active_on?(Date.current + 5)
    assert_not entitlement.active_on?(Date.current + 11)
    assert_not entitlement.active_on?(Date.current - 1)
  end

  test "overrides persist and mark the entitlement as negotiated" do
    institution = build_institution
    addon = build_addon
    entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: addon,
      valid_from: Date.current, override_monthly_fee_cents: 500_000, override_currency: "COP")

    assert entitlement.negotiated?
    assert_equal 500_000, entitlement.reload.override_monthly_fee_cents
  end

  test "the DB partial unique index backstops one active entitlement per institution+addon" do
    institution = build_institution
    addon = build_addon
    ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current)

    duplicate = ControlPlane::Entitlement.new(institution: institution, addon: addon,
      valid_from: Date.current, status: "active")
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
