require "test_helper"

class ControlPlane::InvoicesTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)

    @institution = Core::Institution.create!(name: "Colegio Facturas", slug: "colegio-facturas",
      code: "INV-1", kind: "school")
    plan = ControlPlane::Plan.create!(key: "k12_standard", name: "K12 Estándar",
      base_price_per_student_cents: 300_000, currency: "COP")
    plan.price_tiers.create!(min_students: 1, max_students: nil, price_per_student_cents: 300_000)
    ControlPlane::Subscription.sign!(institution: @institution, plan: plan, starts_on: 6.months.ago.to_date)
    ControlPlane::StudentHeadcountSnapshot.create!(institution: @institution, as_of_date: Date.new(2026, 6, 15),
      headcount: 100)
  end

  test "generating a draft cuts the invoice and audits it" do
    post control_plane_institution_invoices_path(@institution), params: {
      invoice: { period_start: "2026-06-01", period_end: "2026-06-30" }
    }

    invoice = ControlPlane::Invoice.find_by(institution_id: @institution.id)
    assert invoice.present?
    assert invoice.draft?
    assert_redirected_to control_plane_institution_invoice_path(@institution, invoice)
    assert ControlPlane::AuditEvent.exists?(action: "invoice.drafted", target_id: invoice.id)
  end

  test "generating a draft without an active subscription is rejected with a friendly message" do
    institution = Core::Institution.create!(name: "Colegio Sin Suscripción", slug: "colegio-sin-sub",
      code: "INV-2", kind: "school")

    post control_plane_institution_invoices_path(institution), params: {
      invoice: { period_start: "2026-06-01", period_end: "2026-06-30" }
    }

    assert_response :unprocessable_entity
    assert_equal 0, ControlPlane::Invoice.where(institution_id: institution.id).count
  end

  test "show renders the line items grouped by kind" do
    invoice = ControlPlane::Billing::PeriodCut.call(institution: @institution,
      period_start: Date.new(2026, 6, 1), period_end: Date.new(2026, 6, 30))

    get control_plane_institution_invoice_path(@institution, invoice)
    assert_response :success
    assert_match "Base por alumno", response.body
  end

  test "finalizing freezes the invoice and audits the acting platform_admin" do
    invoice = ControlPlane::Billing::PeriodCut.call(institution: @institution,
      period_start: Date.new(2026, 6, 1), period_end: Date.new(2026, 6, 30))

    patch finalize_control_plane_institution_invoice_path(@institution, invoice)

    assert_equal "finalized", invoice.reload.status
    event = ControlPlane::AuditEvent.find_by(action: "invoice.finalized", target_id: invoice.id)
    assert event.present?
    assert_equal @admin.id, event.platform_admin_id
  end

  test "re-cutting a finalized invoice is rejected with a friendly message, not a 500" do
    invoice = ControlPlane::Billing::PeriodCut.call(institution: @institution,
      period_start: Date.new(2026, 6, 1), period_end: Date.new(2026, 6, 30))
    invoice.finalize!

    patch recut_control_plane_institution_invoice_path(@institution, invoice)
    assert_redirected_to control_plane_institution_invoice_path(@institution, invoice)
    follow_redirect!
    assert_match "ya está finalizada", response.body
  end

  test "voiding a draft works" do
    invoice = ControlPlane::Billing::PeriodCut.call(institution: @institution,
      period_start: Date.new(2026, 6, 1), period_end: Date.new(2026, 6, 30))

    patch void_control_plane_institution_invoice_path(@institution, invoice)
    assert_equal "void", invoice.reload.status
  end

  test "the top-level index lists invoices across institutions" do
    ControlPlane::Billing::PeriodCut.call(institution: @institution,
      period_start: Date.new(2026, 6, 1), period_end: Date.new(2026, 6, 30))

    get control_plane_invoices_path
    assert_response :success
    assert_match @institution.name, response.body
    assert_match "Borrador", response.body
  end

  test "a tenant Core::User cannot reach the invoices screens" do
    delete control_plane_session_path

    tenant_password = "tenant-password-123456"
    institution = Core::Institution.create!(name: "Colegio Facturas Tenant", slug: "colegio-facturas-tenant",
      code: "INV-3", kind: "school")
    user = Core::User.create!(email: "profe@colegio-facturas-tenant.test", name: "Profe", password: tenant_password)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      institution.memberships.create!(user: user)
    end
    sign_in_as(user, institution: institution, password: tenant_password)

    get control_plane_invoices_path
    assert_redirected_to new_control_plane_session_path
  end
end
