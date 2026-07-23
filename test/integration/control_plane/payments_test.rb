require "test_helper"

class ControlPlane::PaymentsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)

    @institution = Core::Institution.create!(name: "Colegio Pagos", slug: "colegio-pagos",
      code: "PAY-1", kind: "school")
    plan = ControlPlane::Plan.create!(key: "k12_standard", name: "K12 Estándar",
      base_price_per_student_cents: 300_000, currency: "COP")
    plan.price_tiers.create!(min_students: 1, max_students: nil, price_per_student_cents: 300_000)
    ControlPlane::Subscription.sign!(institution: @institution, plan: plan, starts_on: 6.months.ago.to_date)
    ControlPlane::StudentHeadcountSnapshot.create!(institution: @institution, as_of_date: Date.new(2026, 6, 15),
      headcount: 100)

    billing_period = ControlPlane::BillingPeriod.create!(institution: @institution,
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    @invoice = ControlPlane::Billing::PeriodCut.call(institution: @institution, billing_period: billing_period)
  end

  test "acceptance: cut an invoice, record two partial payments, balance_due reflects the subtraction" do
    assert_equal 30_000_000, @invoice.subtotal_cents # 100 alumnos * 300_000

    post control_plane_institution_invoice_payments_path(@institution, @invoice),
      params: { amount: "100000.00", method: "cash", paid_on: "2026-06-05", idempotency_key: SecureRandom.uuid }
    post control_plane_institution_invoice_payments_path(@institution, @invoice),
      params: { amount: "50000.00", method: "transfer", paid_on: "2026-06-10", idempotency_key: SecureRandom.uuid }

    @invoice.reload
    assert_equal 2, @invoice.payments.count
    assert_equal 15_000_000, @invoice.paid_cents
    assert_equal 15_000_000, @invoice.balance_due_cents

    get control_plane_institution_invoice_path(@institution, @invoice)
    assert_response :success
    assert_match "Efectivo", response.body
    assert_match "Transferencia", response.body
  end

  test "voiding the invoice hides the payment form" do
    patch void_control_plane_institution_invoice_path(@institution, @invoice)

    get control_plane_institution_invoice_path(@institution, @invoice)
    assert_response :success
    assert_no_match(/name="method"/, response.body)
  end

  test "a tenant Core::User cannot record a payment" do
    delete control_plane_session_path

    tenant_password = "tenant-password-123456"
    user = Core::User.create!(email: "profe@colegio-pagos-tenant.test", name: "Profe", password: tenant_password)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      @institution.memberships.create!(user: user)
    end
    sign_in_as(user, institution: @institution, password: tenant_password)

    post control_plane_institution_invoice_payments_path(@institution, @invoice),
      params: { amount: "1000", method: "cash", paid_on: "2026-06-05" }
    assert_redirected_to new_control_plane_session_path
  end
end
