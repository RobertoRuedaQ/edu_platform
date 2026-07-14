require "test_helper"

class ControlPlane::AddonTest < ActiveSupport::TestCase
  test "a non-metered addon cannot carry metering fields (app validation)" do
    addon = ControlPlane::Addon.new(key: "cafeteria", name: "Cafetería", currency: "COP",
      metered: false, included_quota: 100, unit: "x", overage_unit_price_cents: 10)
    assert_not addon.valid?
    assert_includes addon.errors[:base].join, "no debe tener"
  end

  test "a metered addon requires all three metering fields (app validation)" do
    addon = ControlPlane::Addon.new(key: "transportation", name: "Transporte", currency: "COP", metered: true)
    assert_not addon.valid?
    assert_includes addon.errors[:base].join, "requiere"
  end

  test "the DB CHECK backstops the metering consistency rule" do
    addon = ControlPlane::Addon.create!(key: "counseling", name: "Consejería", currency: "COP", metered: false)

    assert_raises(ActiveRecord::StatementInvalid) do
      addon.update_column(:metered, true) # bypasses AR validations, hits the CHECK
    end
  end

  test "rejects a key outside the addon-able domain list" do
    addon = ControlPlane::Addon.new(key: "identity_access", name: "IAM", currency: "COP")
    assert_not addon.valid?
    assert_includes addon.errors[:key], "no es un dominio addon-able válido"
  end

  test "retire! and reactivate! never destroy the row" do
    addon = ControlPlane::Addon.create!(key: "schedules", name: "Horarios", currency: "COP")
    addon.retire!
    assert_equal "retired", addon.reload.status
    addon.reactivate!
    assert_equal "active", addon.reload.status
  end

  test "monthly_fee divides cents for display" do
    addon = ControlPlane::Addon.create!(key: "finance", name: "Tesorería", currency: "COP", monthly_fee_cents: 123_45)
    assert_equal 123.45, addon.monthly_fee
  end
end
