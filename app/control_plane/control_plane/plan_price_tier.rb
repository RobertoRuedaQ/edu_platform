module ControlPlane
  # One volume bracket of a Plan's per-student base rate. Hard-deletable (no
  # soft-retire): tiers are live config of a plan, not referenced by
  # historical invoices — those snapshot pricing in S2/S4.
  class PlanPriceTier < ApplicationRecord
    self.table_name = "plan_price_tiers"

    belongs_to :plan, class_name: "ControlPlane::Plan"

    validates :min_students, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
    validates :max_students, numericality: { only_integer: true }, allow_nil: true
    validates :price_per_student_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validate :max_greater_than_min
    validate :no_overlap_with_siblings

    def price_per_student = price_per_student_cents / 100.0

    def open_ended? = max_students.nil?

    private

    def max_greater_than_min
      return if max_students.nil? || min_students.nil?
      errors.add(:max_students, "debe ser mayor que el mínimo") if max_students <= min_students
    end

    def no_overlap_with_siblings
      return if min_students.nil?
      siblings = plan.price_tiers.where.not(id: id)
      overlapping = siblings.any? do |other|
        other_max = other.max_students || Float::INFINITY
        this_max = max_students || Float::INFINITY
        min_students < other_max && other.min_students < this_max
      end
      errors.add(:base, "el rango se solapa con otro tier existente de este plan") if overlapping
    end
  end
end
