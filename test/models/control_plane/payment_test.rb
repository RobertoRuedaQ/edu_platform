require "test_helper"

class ControlPlane::PaymentTest < ActiveSupport::TestCase
  def build_invoice
    institution = Core::Institution.create!(name: "Colegio #{SecureRandom.hex(4)}", slug: "pay-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    billing_period = ControlPlane::BillingPeriod.create!(institution: institution,
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    ControlPlane::Invoice.create!(institution: institution, billing_period: billing_period, currency: "COP")
  end

  def build_admin
    ControlPlane::PlatformAdmin.create!(email: "admin-#{SecureRandom.hex(4)}@test.co", name: "Admin",
      password: "secretpass123", role: "super_admin")
  end

  test "amount_cents must be greater than zero" do
    invoice = build_invoice
    payment = ControlPlane::Payment.new(invoice: invoice, amount_cents: 0, method: "cash",
      paid_on: Date.current, recorded_by: build_admin)
    assert_not payment.valid?
  end

  test "method must be one of the known vocabulary" do
    invoice = build_invoice
    payment = ControlPlane::Payment.new(invoice: invoice, amount_cents: 1_000, method: "bitcoin",
      paid_on: Date.current, recorded_by: build_admin)
    assert_not payment.valid?
  end

  test "institution/billing_period delegate to the invoice, never a second source of truth" do
    invoice = build_invoice
    payment = ControlPlane::Payment.create!(institution_id: invoice.institution_id, invoice: invoice,
      amount_cents: 1_000, method: "cash", paid_on: Date.current, recorded_by: build_admin)

    assert_equal invoice.institution, payment.institution
    assert_equal invoice.billing_period, payment.billing_period
  end

  test "amount bridges cents to a BigDecimal, never Float" do
    invoice = build_invoice
    payment = ControlPlane::Payment.create!(institution_id: invoice.institution_id, invoice: invoice,
      amount_cents: 123_45, method: "cash", paid_on: Date.current, recorded_by: build_admin)

    assert_equal BigDecimal("123.45"), payment.amount
    assert_kind_of BigDecimal, payment.amount
  end
end
