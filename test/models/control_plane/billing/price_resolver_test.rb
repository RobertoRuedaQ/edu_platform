require "test_helper"

class ControlPlane::Billing::PriceResolverTest < ActiveSupport::TestCase
  def subscription_with_tiers
    ControlPlane::Subscription.new(
      base_price_per_student_cents: 300_000,
      price_tiers_snapshot: [
        { "min_students" => 1, "max_students" => 500, "price_per_student_cents" => 300_000 },
        { "min_students" => 500, "max_students" => 2_000, "price_per_student_cents" => 250_000 },
        { "min_students" => 2_000, "max_students" => nil, "price_per_student_cents" => 200_000 }
      ]
    )
  end

  test "headcount inside the first tier uses that tier's price" do
    price = ControlPlane::Billing::PriceResolver.per_student_cents(headcount: 300, subscription: subscription_with_tiers)
    assert_equal 300_000, price
  end

  test "headcount inside the middle tier uses that tier's price" do
    price = ControlPlane::Billing::PriceResolver.per_student_cents(headcount: 1_000, subscription: subscription_with_tiers)
    assert_equal 250_000, price
  end

  test "headcount inside the open-ended tier uses that tier's price" do
    price = ControlPlane::Billing::PriceResolver.per_student_cents(headcount: 5_000, subscription: subscription_with_tiers)
    assert_equal 200_000, price
  end

  test "the boundary headcount belongs to the tier it opens (inclusive floor, exclusive ceiling)" do
    # min_students=500 in the middle tier means headcount==500 is IN the middle
    # tier, not the first (whose max_students=500 excludes it) — matches
    # ControlPlane::PlanPriceTier's own overlap-check semantics [min, max).
    price = ControlPlane::Billing::PriceResolver.per_student_cents(headcount: 500, subscription: subscription_with_tiers)
    assert_equal 250_000, price
  end

  test "headcount covered by no tier falls back to the subscription's base price" do
    subscription = ControlPlane::Subscription.new(base_price_per_student_cents: 999_000, price_tiers_snapshot: [])
    price = ControlPlane::Billing::PriceResolver.per_student_cents(headcount: 42, subscription: subscription)
    assert_equal 999_000, price
  end

  test "zero headcount resolves against the tier starting at zero, if any" do
    subscription = ControlPlane::Subscription.new(base_price_per_student_cents: 999_000, price_tiers_snapshot: [
      { "min_students" => 0, "max_students" => 100, "price_per_student_cents" => 111_000 }
    ])
    price = ControlPlane::Billing::PriceResolver.per_student_cents(headcount: 0, subscription: subscription)
    assert_equal 111_000, price
  end
end
