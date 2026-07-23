require "test_helper"

class ControlPlane::Billing::PeriodCutTest < ActiveSupport::TestCase
  PERIOD_START = Date.new(2026, 6, 1)
  PERIOD_END = Date.new(2026, 6, 30)

  def build_institution
    slug = "cut-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def billing_period(institution)
    ControlPlane::BillingPeriod.find_or_create_by!(institution: institution,
      starts_on: PERIOD_START, ends_on: PERIOD_END)
  end

  def build_plan_with_tiers
    plan = ControlPlane::Plan.create!(key: "plan-#{SecureRandom.hex(4)}", name: "Plan de prueba",
      base_price_per_student_cents: 300_000, currency: "COP")
    plan.price_tiers.create!(min_students: 1, max_students: 500, price_per_student_cents: 300_000)
    plan.price_tiers.create!(min_students: 500, max_students: nil, price_per_student_cents: 250_000)
    plan
  end

  def sign_subscription(institution, plan = build_plan_with_tiers)
    ControlPlane::Subscription.sign!(institution: institution, plan: plan, starts_on: PERIOD_START - 6.months)
  end

  def full_scenario
    institution = build_institution
    subscription = sign_subscription(institution)

    counseling = ControlPlane::Addon.create!(key: "counseling", name: "Consejería", currency: "COP",
      monthly_fee_cents: 600_000)
    counseling_entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: counseling,
      valid_from: PERIOD_START - 1.month, override_monthly_fee_cents: 500_000)

    transportation = ControlPlane::Addon.create!(key: "transportation", name: "Transporte", currency: "COP",
      metered: true, unit: "check-ins", included_quota: 100, overage_unit_price_cents: 10, monthly_fee_cents: 400_000)
    transport_entitlement = ControlPlane::Entitlement.create!(institution: institution, addon: transportation,
      valid_from: PERIOD_START - 1.month, override_included_quota: 50, override_unit_price_cents: 15)

    snapshot = ControlPlane::StudentHeadcountSnapshot.create!(institution: institution,
      as_of_date: Date.new(2026, 6, 15), headcount: 600)

    ControlPlane::UsageDailyRollup.create!(institution: institution, addon: transportation, unit: "check-ins",
      usage_date: Date.new(2026, 6, 10), total_quantity: 50, event_count: 5)
    ControlPlane::UsageDailyRollup.create!(institution: institution, addon: transportation, unit: "check-ins",
      usage_date: Date.new(2026, 6, 20), total_quantity: 30, event_count: 3)

    {
      institution: institution, subscription: subscription, snapshot: snapshot,
      counseling: counseling, counseling_entitlement: counseling_entitlement,
      transportation: transportation, transport_entitlement: transport_entitlement
    }
  end

  test "produces a draft with base_seats, addon_fee, and usage_overage lines, subtotal = sum" do
    s = full_scenario

    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution],
      billing_period: billing_period(s[:institution]))

    assert invoice.draft?
    kinds = invoice.line_items.pluck(:kind).sort
    assert_equal %w[addon_fee addon_fee base_seats usage_overage], kinds
    assert_equal invoice.line_items.sum(:amount_cents), invoice.subtotal_cents
    assert ControlPlane::AuditEvent.exists?(action: "invoice.drafted", target_id: invoice.id)
  end

  test "base_seats uses the tier the headcount falls into (H4)" do
    s = full_scenario # headcount 600 -> second tier, 250_000/student
    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution],
      billing_period: billing_period(s[:institution]))

    base_line = invoice.line_items.find_by(kind: "base_seats")
    assert_equal 600, base_line.quantity.to_i
    assert_equal 250_000, base_line.unit_price_cents
    assert_equal 600 * 250_000, base_line.amount_cents
  end

  test "headcount outside every tier falls back to the subscription base price" do
    institution = build_institution
    plan = ControlPlane::Plan.create!(key: "plan-#{SecureRandom.hex(4)}", name: "Plan sin tiers",
      base_price_per_student_cents: 999_000, currency: "COP")
    subscription = sign_subscription(institution, plan)
    ControlPlane::StudentHeadcountSnapshot.create!(institution: institution, as_of_date: Date.new(2026, 6, 15),
      headcount: 42)

    invoice = ControlPlane::Billing::PeriodCut.call(institution: institution, billing_period: billing_period(institution))

    base_line = invoice.line_items.find_by(kind: "base_seats")
    assert_equal 999_000, base_line.unit_price_cents
  end

  test "overrides win over the catalog for both addon_fee and usage_overage (H3)" do
    s = full_scenario
    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution],
      billing_period: billing_period(s[:institution]))

    counseling_fee = invoice.line_items.find_by(kind: "addon_fee", addon_id: s[:counseling].id)
    assert_equal 500_000, counseling_fee.unit_price_cents # override, not the catalog's 600_000
    assert counseling_fee.source_ref["override_applied"]

    transport_fee = invoice.line_items.find_by(kind: "addon_fee", addon_id: s[:transportation].id)
    assert_equal 400_000, transport_fee.unit_price_cents # no fee override on this entitlement
    assert_not transport_fee.source_ref["override_applied"]

    overage = invoice.line_items.find_by(kind: "usage_overage")
    assert_equal 15, overage.unit_price_cents # override, not the catalog's 10
    assert overage.source_ref["override_applied"]
  end

  test "usage_overage quantity is usage minus quota, using the override quota (H7)" do
    s = full_scenario # usage 50+30=80, override quota 50 -> overage 30
    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution],
      billing_period: billing_period(s[:institution]))

    overage = invoice.line_items.find_by(kind: "usage_overage")
    assert_equal 30, overage.quantity.to_i
    assert_equal 30 * 15, overage.amount_cents
    assert_equal 80, overage.source_ref["usage_total"]
    assert_equal 50, overage.source_ref["quota_applied"]
  end

  test "usage at or below quota produces no overage line" do
    s = full_scenario
    ControlPlane::UsageDailyRollup.where(institution_id: s[:institution].id).destroy_all
    ControlPlane::UsageDailyRollup.create!(institution: s[:institution], addon: s[:transportation], unit: "check-ins",
      usage_date: Date.new(2026, 6, 10), total_quantity: 20, event_count: 2) # under the 50 override quota

    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution],
      billing_period: billing_period(s[:institution]))

    assert_nil invoice.line_items.find_by(kind: "usage_overage")
  end

  test "empty rollups (pre-S3b reality) produce zero overage without breaking the rest of the invoice" do
    s = full_scenario
    ControlPlane::UsageDailyRollup.where(institution_id: s[:institution].id).destroy_all

    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution],
      billing_period: billing_period(s[:institution]))

    assert_nil invoice.line_items.find_by(kind: "usage_overage")
    assert invoice.line_items.find_by(kind: "base_seats").present?
    assert_equal invoice.line_items.sum(:amount_cents), invoice.subtotal_cents
  end

  test "re-cutting the same period replaces lines in place, does not duplicate (H1)" do
    s = full_scenario
    period = billing_period(s[:institution])
    first = ControlPlane::Billing::PeriodCut.call(institution: s[:institution], billing_period: period)
    first_count = first.line_items.count

    second = ControlPlane::Billing::PeriodCut.call(institution: s[:institution], billing_period: period)

    assert_equal first.id, second.id
    assert_equal first_count, second.line_items.count
    assert ControlPlane::AuditEvent.exists?(action: "invoice.redrafted", target_id: first.id)
  end

  test "re-cutting the same period never creates a second BillingPeriod" do
    s = full_scenario
    period = billing_period(s[:institution])
    ControlPlane::Billing::PeriodCut.call(institution: s[:institution], billing_period: period)
    ControlPlane::Billing::PeriodCut.call(institution: s[:institution], billing_period: billing_period(s[:institution]))

    assert_equal 1, ControlPlane::BillingPeriod.where(institution_id: s[:institution].id).count
  end

  test "re-cutting a finalized invoice is rejected" do
    s = full_scenario
    period = billing_period(s[:institution])
    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution], billing_period: period)
    invoice.finalize!

    assert_raises(ControlPlane::Billing::PeriodCut::AlreadyFinalized) do
      ControlPlane::Billing::PeriodCut.call(institution: s[:institution], billing_period: period)
    end
  end

  test "no active subscription rejects the cut (H9)" do
    institution = build_institution
    assert_raises(ControlPlane::Billing::PeriodCut::NoActiveSubscription) do
      ControlPlane::Billing::PeriodCut.call(institution: institution, billing_period: billing_period(institution))
    end
  end

  test "an ended subscription (even if it once covered the period) also rejects the cut" do
    institution = build_institution
    subscription = sign_subscription(institution)
    subscription.end!(ends_on: PERIOD_END + 1)

    assert_raises(ControlPlane::Billing::PeriodCut::NoActiveSubscription) do
      ControlPlane::Billing::PeriodCut.call(institution: institution, billing_period: billing_period(institution))
    end
  end

  test "no headcount snapshot omits base_seats and flags a note, rest of invoice still cuts (H2)" do
    institution = build_institution
    sign_subscription(institution)

    invoice = ControlPlane::Billing::PeriodCut.call(institution: institution, billing_period: billing_period(institution))

    assert invoice.draft?
    assert_nil invoice.line_items.find_by(kind: "base_seats")
    assert_match "headcount", invoice.notes
    assert_equal 0, invoice.subtotal_cents
  end

  test "runs with no tenant GUC set at all" do
    s = full_scenario
    assert_nil ActiveRecord::Base.uncached {
      ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_institution_id', true)").presence
    }

    ControlPlane::Billing::PeriodCut.call(institution: s[:institution], billing_period: billing_period(s[:institution]))

    assert_nil ActiveRecord::Base.uncached {
      ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_institution_id', true)").presence
    }
  end

  test "a currency mismatch on an override is flagged in notes, not silently applied" do
    s = full_scenario
    s[:counseling_entitlement].update!(override_currency: "USD")

    invoice = ControlPlane::Billing::PeriodCut.call(institution: s[:institution],
      billing_period: billing_period(s[:institution]))

    assert_match "Moneda de override", invoice.notes
    assert_equal "COP", invoice.currency # still the subscription's single currency (H5)
  end
end
