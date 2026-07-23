require "test_helper"

class ControlPlane::Billing::PaymentRecorderTest < ActiveSupport::TestCase
  def build_invoice
    institution = Core::Institution.create!(name: "Colegio #{SecureRandom.hex(4)}", slug: "prec-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    billing_period = ControlPlane::BillingPeriod.create!(institution: institution,
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    ControlPlane::Invoice.create!(institution: institution, billing_period: billing_period, currency: "COP")
  end

  def build_admin
    ControlPlane::PlatformAdmin.create!(email: "admin-#{SecureRandom.hex(4)}@test.co", name: "Admin",
      password: "secretpass123", role: "super_admin")
  end

  test "records a payment and audits it" do
    invoice = build_invoice
    admin = build_admin

    payment = ControlPlane::Billing::PaymentRecorder.call(invoice: invoice, amount_cents: 5_000, method: "cash",
      recorded_by: admin)

    assert payment.persisted?
    assert_equal 5_000, payment.amount_cents
    assert ControlPlane::AuditEvent.exists?(action: "payment.recorded", target_id: payment.id,
      platform_admin_id: admin.id)
  end

  test "idempotent: resending the same idempotency_key returns the existing payment, never a second one" do
    invoice = build_invoice
    admin = build_admin
    key = SecureRandom.uuid

    first = ControlPlane::Billing::PaymentRecorder.call(invoice: invoice, amount_cents: 5_000, method: "cash",
      recorded_by: admin, idempotency_key: key)
    second = ControlPlane::Billing::PaymentRecorder.call(invoice: invoice, amount_cents: 5_000, method: "cash",
      recorded_by: admin, idempotency_key: key)

    assert_equal first.id, second.id
    assert_equal 1, ControlPlane::Payment.where(invoice: invoice).count
  end

  test "rejects an invalid amount" do
    invoice = build_invoice
    assert_raises(ActiveRecord::RecordInvalid) do
      ControlPlane::Billing::PaymentRecorder.call(invoice: invoice, amount_cents: 0, method: "cash",
        recorded_by: build_admin)
    end
  end
end
