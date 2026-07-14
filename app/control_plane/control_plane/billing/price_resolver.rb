module ControlPlane
  module Billing
    # Pure, unit-testable (no DB) resolution of "what does one student cost"
    # for a given headcount, from a subscription's FROZEN snapshot (H4). Never
    # reads the live catalog (plans/plan_price_tiers) — that snapshot is
    # immutable once signed (S2a).
    #
    # FLAT resolution: the whole headcount prices at the ONE tier that
    # contains it, never graduated/marginal pricing. Range semantics match
    # ControlPlane::PlanPriceTier's own overlap check: [min_students,
    # max_students) — inclusive floor, EXCLUSIVE ceiling (nil ceiling = open-
    # ended). If no tier covers the headcount, falls back to the
    # subscription's own base_price_per_student_cents.
    module PriceResolver
      module_function

      def per_student_cents(headcount:, subscription:)
        tier = subscription.price_tiers_snapshot.find do |t|
          min = t["min_students"]
          max = t["max_students"]
          headcount >= min && (max.nil? || headcount < max)
        end

        tier ? tier["price_per_student_cents"] : subscription.base_price_per_student_cents
      end
    end
  end
end
