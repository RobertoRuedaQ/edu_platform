module ControlPlane
  # GLOBAL catalog row — base per-student rate + volume brackets
  # (plan_price_tiers). F9: independent from Addon, no FK between catalogs.
  #
  # Pricing SEMANTICS (documented for S4, not implemented here): the
  # per-student price for a given headcount is the price_per_student_cents of
  # the tier whose [min_students, max_students) range contains it; if no tier
  # covers it, base_price_per_student_cents applies. S1 only stores this;
  # applying it to an actual headcount/invoice is S4.
  class Plan < ApplicationRecord
    self.table_name = "plans"

    has_many :price_tiers, -> { order(:min_students) },
      class_name: "ControlPlane::PlanPriceTier", foreign_key: :plan_id, dependent: :destroy

    validates :key, presence: true, uniqueness: true
    validates :name, presence: true
    validates :currency, presence: true, length: { is: 3 }
    validates :status, inclusion: { in: %w[active retired] }
    validates :base_price_per_student_cents, numericality: { greater_than_or_equal_to: 0 }

    scope :active, -> { where(status: "active") }
    scope :retired, -> { where(status: "retired") }

    def active? = status == "active"

    def retire!     = update!(status: "retired")
    def reactivate! = update!(status: "active")

    def base_price_per_student = base_price_per_student_cents / 100.0
  end
end
