require "test_helper"

class ControlPlane::UsageDailyRollupTest < ActiveSupport::TestCase
  def build_institution
    slug = "udr-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_metered_addon
    ControlPlane::Addon.create!(key: "transportation", name: "Transporte", currency: "COP",
      metered: true, unit: "check-ins", included_quota: 100, overage_unit_price_cents: 10)
  end

  test "one rollup per institution+addon+unit+usage_date" do
    institution = build_institution
    addon = build_metered_addon
    ControlPlane::UsageDailyRollup.create!(institution: institution, addon: addon, unit: "check-ins",
      usage_date: Date.current, total_quantity: 10, event_count: 2)

    duplicate = ControlPlane::UsageDailyRollup.new(institution: institution, addon: addon, unit: "check-ins",
      usage_date: Date.current, total_quantity: 99, event_count: 99)
    assert_not duplicate.valid?
  end

  test "rollups are NOT readonly — they recompute in place" do
    institution = build_institution
    addon = build_metered_addon
    rollup = ControlPlane::UsageDailyRollup.create!(institution: institution, addon: addon, unit: "check-ins",
      usage_date: Date.current, total_quantity: 10, event_count: 2)

    rollup.update!(total_quantity: 15, event_count: 3)
    assert_equal 15, rollup.reload.total_quantity
  end

  test "total_quantity and event_count cannot be negative" do
    institution = build_institution
    addon = build_metered_addon
    rollup = ControlPlane::UsageDailyRollup.new(institution: institution, addon: addon, unit: "check-ins",
      usage_date: Date.current, total_quantity: -1, event_count: 0)
    assert_not rollup.valid?
  end
end
