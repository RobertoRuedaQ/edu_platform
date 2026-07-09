require "test_helper"

class ControlPlane::InstitutionsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)

    @institution = Core::Institution.create!(name: "Colegio Hub", slug: "colegio-hub",
      code: "HUB-1", kind: "school")
  end

  test "index lists institutions read-only, no create action" do
    get control_plane_institutions_path
    assert_response :success
    assert_match @institution.name, response.body
  end

  test "there is no route to create or edit an institution" do
    post control_plane_institutions_path, params: { institution: { name: "Nueva" } }
    assert_response :not_found
  end

  test "show renders without a subscription or entitlements" do
    get control_plane_institution_path(@institution)
    assert_response :success
    assert_match "no tiene una suscripción activa", response.body
  end

  test "show surfaces the active subscription and entitlements once they exist" do
    plan = ControlPlane::Plan.create!(key: "k12_standard", name: "K12 Estándar",
      base_price_per_student_cents: 300_000, currency: "COP")
    ControlPlane::Subscription.sign!(institution: @institution, plan: plan, starts_on: 1.month.ago.to_date)
    addon = ControlPlane::Addon.create!(key: "cafeteria", name: "Cafetería", currency: "COP")
    ControlPlane::Entitlement.create!(institution: @institution, addon: addon, valid_from: Date.current)

    get control_plane_institution_path(@institution)
    assert_response :success
    assert_match "k12_standard".humanize, response.body
    assert_match "Cafetería", response.body
  end
end
