require "test_helper"

class ControlPlane::SubscriptionTest < ActiveSupport::TestCase
  def build_institution
    slug = "sub-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_plan(key: "plan_#{SecureRandom.hex(4)}")
    plan = ControlPlane::Plan.create!(key: key, name: "Plan de prueba", base_price_per_student_cents: 300_000,
      currency: "COP")
    plan.price_tiers.create!(min_students: 1, max_students: 500, price_per_student_cents: 300_000)
    plan.price_tiers.create!(min_students: 501, max_students: nil, price_per_student_cents: 250_000)
    plan
  end

  test "sign! snapshots the plan's scalars and tiers immutably" do
    institution = build_institution
    plan = build_plan

    subscription = ControlPlane::Subscription.sign!(institution: institution, plan: plan)

    assert_equal plan.key, subscription.plan_key
    assert_equal plan.base_price_per_student_cents, subscription.base_price_per_student_cents
    assert_equal plan.currency, subscription.currency
    assert_equal 2, subscription.price_tiers_snapshot.size
    assert_equal 300_000, subscription.price_tiers_snapshot.first["price_per_student_cents"]
    assert subscription.active?
  end

  test "editing the live plan afterwards does not change an already-signed subscription's snapshot" do
    institution = build_institution
    plan = build_plan
    subscription = ControlPlane::Subscription.sign!(institution: institution, plan: plan)

    plan.update!(base_price_per_student_cents: 999_999)
    plan.price_tiers.first.update!(price_per_student_cents: 111_111)

    subscription.reload
    assert_equal 300_000, subscription.base_price_per_student_cents
    assert_equal 300_000, subscription.price_tiers_snapshot.first["price_per_student_cents"]
  end

  test "only one active subscription per institution" do
    institution = build_institution
    plan = build_plan
    ControlPlane::Subscription.sign!(institution: institution, plan: plan)

    assert_raises(ActiveRecord::RecordInvalid) do
      ControlPlane::Subscription.sign!(institution: institution, plan: plan)
    end
  end

  test "ending the active subscription allows signing a new one" do
    institution = build_institution
    plan = build_plan
    first = ControlPlane::Subscription.sign!(institution: institution, plan: plan, starts_on: 1.month.ago.to_date)

    first.end!
    assert_equal "ended", first.reload.status
    assert_equal Date.current, first.ends_on

    second = ControlPlane::Subscription.sign!(institution: institution, plan: plan)
    assert second.active?
  end

  test "ends_on must be after starts_on" do
    institution = build_institution
    plan = build_plan
    subscription = ControlPlane::Subscription.sign!(institution: institution, plan: plan)

    assert_raises(ActiveRecord::RecordInvalid) { subscription.end!(ends_on: subscription.starts_on) }
  end

  test "the DB partial unique index backstops one active subscription per institution" do
    institution = build_institution
    plan = build_plan
    ControlPlane::Subscription.sign!(institution: institution, plan: plan, starts_on: 1.month.ago.to_date)

    duplicate = ControlPlane::Subscription.new(
      institution: institution, plan: plan, plan_key: plan.key,
      base_price_per_student_cents: plan.base_price_per_student_cents, currency: plan.currency,
      price_tiers_snapshot: [], starts_on: Date.current, status: "active"
    )
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
