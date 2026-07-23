require "test_helper"

class ControlPlane::InvoiceLineItemTest < ActiveSupport::TestCase
  def build_invoice
    institution = Core::Institution.create!(name: "Colegio #{SecureRandom.hex(4)}", slug: "ili-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    billing_period = ControlPlane::BillingPeriod.create!(institution: institution,
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    ControlPlane::Invoice.create!(institution: institution, billing_period: billing_period, currency: "COP")
  end

  def build_addon
    ControlPlane::Addon.create!(key: "counseling", name: "Consejería", currency: "COP")
  end

  test "base_seats requires a nil addon_id" do
    invoice = build_invoice
    line = ControlPlane::InvoiceLineItem.new(invoice: invoice, kind: "base_seats", description: "Base",
      quantity: 10, unit_price_cents: 1_000, amount_cents: 10_000, addon: build_addon)
    assert_not line.valid?
    assert_includes line.errors[:addon_id].join, "vacío"
  end

  test "addon_fee requires an addon_id" do
    invoice = build_invoice
    line = ControlPlane::InvoiceLineItem.new(invoice: invoice, kind: "addon_fee", description: "Fee",
      quantity: 1, unit_price_cents: 1_000, amount_cents: 1_000, addon: nil)
    assert_not line.valid?
    assert_includes line.errors[:addon_id].join, "requerido"
  end

  test "append-only: allows create but blocks update and destroy" do
    invoice = build_invoice
    line = invoice.line_items.create!(kind: "base_seats", description: "Base", quantity: 10,
      unit_price_cents: 1_000, amount_cents: 10_000)

    assert line.persisted?
    assert line.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { line.update!(amount_cents: 20_000) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { line.destroy! }
  end

  test "delete_all bypasses readonly? for bulk regeneration (PeriodCut's re-cut mechanism)" do
    invoice = build_invoice
    invoice.line_items.create!(kind: "base_seats", description: "Base", quantity: 10,
      unit_price_cents: 1_000, amount_cents: 10_000)

    assert_nothing_raised { invoice.line_items.delete_all }
    assert_equal 0, invoice.line_items.count
  end

  test "unit_price and amount are cents divided for display" do
    invoice = build_invoice
    line = invoice.line_items.create!(kind: "base_seats", description: "Base", quantity: 10,
      unit_price_cents: 123_45, amount_cents: 1_234_50)
    assert_equal 123.45, line.unit_price
    assert_equal 1234.50, line.amount
  end
end
