require "test_helper"

class ControlPlane::SubscriptionsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)

    @institution = Core::Institution.create!(name: "Colegio Suscripciones", slug: "colegio-subs",
      code: "SUB-1", kind: "school")
    @plan = ControlPlane::Plan.create!(key: "k12_standard", name: "K12 Estándar",
      base_price_per_student_cents: 300_000, currency: "COP")
    @plan.price_tiers.create!(min_students: 1, max_students: 500, price_per_student_cents: 300_000)
  end

  test "signing a subscription snapshots the plan and audits it" do
    post control_plane_institution_subscriptions_path(@institution), params: {
      subscription: { plan_id: @plan.id, starts_on: 1.month.ago.to_date }
    }

    subscription = ControlPlane::Subscription.find_by(institution_id: @institution.id)
    assert subscription.present?
    assert_equal @plan.key, subscription.plan_key
    assert_equal 1, subscription.price_tiers_snapshot.size
    assert ControlPlane::AuditEvent.exists?(action: "subscription.signed", target_id: subscription.id)

    @plan.update!(base_price_per_student_cents: 999_999)
    assert_equal 300_000, subscription.reload.base_price_per_student_cents
  end

  test "a second active subscription for the same institution is rejected" do
    post control_plane_institution_subscriptions_path(@institution), params: {
      subscription: { plan_id: @plan.id, starts_on: 1.month.ago.to_date }
    }
    assert_equal 1, ControlPlane::Subscription.where(institution_id: @institution.id).count

    post control_plane_institution_subscriptions_path(@institution), params: {
      subscription: { plan_id: @plan.id, starts_on: Date.current }
    }
    assert_equal 1, ControlPlane::Subscription.active.where(institution_id: @institution.id).count
  end

  test "ending the active subscription allows signing a new one" do
    post control_plane_institution_subscriptions_path(@institution), params: {
      subscription: { plan_id: @plan.id, starts_on: 1.month.ago.to_date }
    }
    first = ControlPlane::Subscription.active.find_by!(institution_id: @institution.id)

    patch terminate_control_plane_institution_subscription_path(@institution, first)
    assert_equal "ended", first.reload.status
    assert ControlPlane::AuditEvent.exists?(action: "subscription.ended", target_id: first.id)

    post control_plane_institution_subscriptions_path(@institution), params: {
      subscription: { plan_id: @plan.id, starts_on: Date.current }
    }
    assert_equal 1, ControlPlane::Subscription.active.where(institution_id: @institution.id).count
  end

  test "a tenant Core::User cannot reach the subscriptions screen" do
    delete control_plane_session_path

    tenant_password = "tenant-password-123456"
    institution = Core::Institution.create!(name: "Colegio Subs Tenant", slug: "colegio-subs-tenant",
      code: "SUB-2", kind: "school")
    user = Core::User.create!(email: "profe@colegio-subs-tenant.test", name: "Profe", password: tenant_password)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      institution.memberships.create!(user: user)
    end
    sign_in_as(user, institution: institution, password: tenant_password)

    get new_control_plane_institution_subscription_path(institution)
    assert_redirected_to new_control_plane_session_path
  end
end
