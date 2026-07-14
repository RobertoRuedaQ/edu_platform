require "test_helper"

class ControlPlane::InvoiceTest < ActiveSupport::TestCase
  def build_institution
    slug = "inv-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_invoice(institution)
    ControlPlane::Invoice.create!(institution: institution, period_start: Date.new(2026, 6, 1),
      period_end: Date.new(2026, 6, 30), currency: "COP")
  end

  test "one non-void invoice per institution+period" do
    institution = build_institution
    build_invoice(institution)

    duplicate = ControlPlane::Invoice.new(institution: institution, period_start: Date.new(2026, 6, 1),
      period_end: Date.new(2026, 6, 30), currency: "COP")
    assert_not duplicate.valid?
  end

  test "a voided invoice does not block a fresh one for the same period" do
    institution = build_institution
    first = build_invoice(institution)
    first.void!

    fresh = ControlPlane::Invoice.new(institution: institution, period_start: Date.new(2026, 6, 1),
      period_end: Date.new(2026, 6, 30), currency: "COP")
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

  test "period_end must not be before period_start" do
    institution = build_institution
    invoice = ControlPlane::Invoice.new(institution: institution, period_start: Date.new(2026, 6, 30),
      period_end: Date.new(2026, 6, 1), currency: "COP")
    assert_not invoice.valid?
  end
end
