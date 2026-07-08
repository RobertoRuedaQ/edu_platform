require "test_helper"

class ControlPlane::PlansTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)
  end

  test "creates a plan and audits it" do
    post control_plane_plans_path, params: { plan: {
      key: "k12_standard", name: "K-12 Estándar", base_price_per_student_cents: 300_000, currency: "COP"
    } }

    plan = ControlPlane::Plan.find_by(key: "k12_standard")
    assert plan.present?
    assert ControlPlane::AuditEvent.exists?(action: "plan.created", target_id: plan.id)
  end

  test "adds non-overlapping tiers, rejects an overlapping one, and deletes a tier" do
    plan = ControlPlane::Plan.create!(key: "growth", name: "Crecimiento",
      base_price_per_student_cents: 300_000, currency: "COP")

    post control_plane_plan_price_tiers_path(plan), params: { plan_price_tier: {
      min_students: 1, max_students: 500, price_per_student_cents: 300_000
    } }
    post control_plane_plan_price_tiers_path(plan), params: { plan_price_tier: {
      min_students: 501, max_students: nil, price_per_student_cents: 250_000
    } }
    assert_equal 2, plan.price_tiers.count

    post control_plane_plan_price_tiers_path(plan), params: { plan_price_tier: {
      min_students: 400, max_students: 600, price_per_student_cents: 280_000
    } }
    assert_equal 2, plan.price_tiers.count, "overlapping tier must be rejected"
    assert ControlPlane::AuditEvent.exists?(action: "plan_price_tier.created")

    tier = plan.price_tiers.find_by(min_students: 1)
    delete control_plane_plan_price_tier_path(plan, tier)
    assert_equal 1, plan.price_tiers.count
    assert ControlPlane::AuditEvent.exists?(action: "plan_price_tier.deleted")
  end

  test "retiring and reactivating a plan is soft and audited" do
    plan = ControlPlane::Plan.create!(key: "starter", name: "Base",
      base_price_per_student_cents: 200_000, currency: "COP")

    patch retire_control_plane_plan_path(plan)
    assert_equal "retired", plan.reload.status
    assert ControlPlane::Plan.exists?(id: plan.id) # never destroyed

    patch reactivate_control_plane_plan_path(plan)
    assert_equal "active", plan.reload.status
  end
end
