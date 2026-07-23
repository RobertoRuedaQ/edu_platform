require "test_helper"

class ControlPlane::InvoiceTest < ActiveSupport::TestCase
  def build_institution
    slug = "inv-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_billing_period(institution, starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    ControlPlane::BillingPeriod.create!(institution: institution, starts_on: starts_on, ends_on: ends_on)
  end

  def build_invoice(institution, billing_period: build_billing_period(institution))
    ControlPlane::Invoice.create!(institution: institution, billing_period: billing_period, currency: "COP")
  end

  test "one non-void invoice per billing period" do
    institution = build_institution
    billing_period = build_billing_period(institution)
    build_invoice(institution, billing_period: billing_period)

    duplicate = ControlPlane::Invoice.new(institution: institution, billing_period: billing_period, currency: "COP")
    assert_not duplicate.valid?
  end

  test "a voided invoice does not block a fresh one for the same period" do
    institution = build_institution
    billing_period = build_billing_period(institution)
    first = build_invoice(institution, billing_period: billing_period)
    first.void!

    fresh = ControlPlane::Invoice.new(institution: institution, billing_period: billing_period, currency: "COP")
    assert fresh.valid?
  end

  test "finalize! only works from draft, freezes subtotal and finalized_at" do
    institution = build_institution
    invoice = build_invoice(institution)
    invoice.line_items.create!(kind: "base_seats", description: "Base", quantity: 10,
      unit_price_cents: 1_000, amount_cents: 10_000)

    invoice.finalize!
    assert invoice.finalized?
    assert_equal 10_000, invoice.subtotal_cents
    assert_not_nil invoice.finalized_at

    assert_raises(ControlPlane::Invoice::InvalidTransition) { invoice.finalize! }
  end

  test "void! is rejected once finalized" do
    institution = build_institution
    invoice = build_invoice(institution)
    invoice.finalize!

    assert_raises(ControlPlane::Invoice::InvalidTransition) { invoice.void! }
  end

  test "void! works from draft" do
    institution = build_institution
    invoice = build_invoice(institution)
    invoice.void!
    assert invoice.void?
  end

  test "period_start/period_end delegate to the billing_period" do
    institution = build_institution
    billing_period = build_billing_period(institution, starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    invoice = build_invoice(institution, billing_period: billing_period)

    assert_equal Date.new(2026, 6, 1), invoice.period_start
    assert_equal Date.new(2026, 6, 30), invoice.period_end
  end

  test "paid_cents/balance_due_cents reflect zero, one, and many payments" do
    institution = build_institution
    invoice = build_invoice(institution)
    invoice.line_items.create!(kind: "base_seats", description: "Base", quantity: 10,
      unit_price_cents: 1_000, amount_cents: 10_000)
    invoice.recompute_subtotal!

    assert_equal 0, invoice.paid_cents
    assert_equal 10_000, invoice.balance_due_cents

    admin = ControlPlane::PlatformAdmin.create!(email: "admin-#{SecureRandom.hex(4)}@test.co", name: "Admin",
      password: "secretpass123", role: "super_admin")
    invoice.payments.create!(institution_id: institution.id, amount_cents: 4_000, method: "cash",
      paid_on: Date.current, recorded_by: admin)
    invoice.payments.create!(institution_id: institution.id, amount_cents: 2_000, method: "transfer",
      paid_on: Date.current, recorded_by: admin)

    assert_equal 6_000, invoice.paid_cents
    assert_equal 4_000, invoice.balance_due_cents
    assert_equal BigDecimal("60.00"), invoice.paid_amount
    assert_equal BigDecimal("40.00"), invoice.balance_due_amount
  end
end
