require "test_helper"

class ControlPlane::PlanPriceTierTest < ActiveSupport::TestCase
  setup do
    @plan = ControlPlane::Plan.create!(key: "enterprise", name: "Institucional",
      base_price_per_student_cents: 200_000, currency: "COP")
  end

  test "accepts non-overlapping tiers" do
    @plan.price_tiers.create!(min_students: 1, max_students: 500, price_per_student_cents: 300_000)
    tier = @plan.price_tiers.create!(min_students: 500, max_students: nil, price_per_student_cents: 250_000)
    assert tier.persisted?
  end

  test "rejects a tier that overlaps an existing one" do
    @plan.price_tiers.create!(min_students: 1, max_students: 500, price_per_student_cents: 300_000)
    tier = @plan.price_tiers.build(min_students: 300, max_students: 600, price_per_student_cents: 280_000)
    assert_not tier.valid?
    assert_includes tier.errors[:base].join, "se solapa"
  end

  test "rejects max_students not greater than min_students" do
    tier = @plan.price_tiers.build(min_students: 100, max_students: 100, price_per_student_cents: 300_000)
    assert_not tier.valid?
    assert_includes tier.errors[:max_students].join, "mayor"
  end

  test "an open-ended tier (max_students nil) still detects overlap with a later tier" do
    @plan.price_tiers.create!(min_students: 500, max_students: nil, price_per_student_cents: 250_000)
    tier = @plan.price_tiers.build(min_students: 1_000, max_students: 2_000, price_per_student_cents: 200_000)
    assert_not tier.valid?
  end

  test "deleting a tier is a hard delete" do
    tier = @plan.price_tiers.create!(min_students: 1, max_students: 500, price_per_student_cents: 300_000)
    tier.destroy!
    assert_not ControlPlane::PlanPriceTier.exists?(id: tier.id)
  end
end
