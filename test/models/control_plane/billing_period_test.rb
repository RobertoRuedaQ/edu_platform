require "test_helper"

class ControlPlane::BillingPeriodTest < ActiveSupport::TestCase
  def build_institution
    slug = "bp-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "ends_on must not be before starts_on" do
    institution = build_institution
    period = ControlPlane::BillingPeriod.new(institution: institution,
      starts_on: Date.new(2026, 6, 30), ends_on: Date.new(2026, 6, 1))
    assert_not period.valid?
  end

  test "unique (institution, starts_on, ends_on), even bypassing model validation" do
    institution = build_institution
    ControlPlane::BillingPeriod.create!(institution: institution,
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))

    duplicate = ControlPlane::BillingPeriod.new(institution: institution,
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "cannot be destroyed while it has invoices" do
    institution = build_institution
    period = ControlPlane::BillingPeriod.create!(institution: institution,
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    ControlPlane::Invoice.create!(institution: institution, billing_period: period, currency: "COP")

    assert_raises(ActiveRecord::DeleteRestrictionError) { period.destroy! }
  end
end
