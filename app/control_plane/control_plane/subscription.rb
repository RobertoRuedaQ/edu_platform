module ControlPlane
  # GLOBAL — a control-plane contract between the platform and one
  # institution (Core::Institution, referenced by a plain FK, never RLS
  # scope). F15: the plan's tarifa is frozen as an IMMUTABLE snapshot at
  # signing time (plan_key/base_price_per_student_cents/currency scalars +
  # price_tiers_snapshot jsonb). plan_id is provenance only — editing the
  # live ControlPlane::Plan afterwards never changes an existing subscription.
  #
  # No #update of terms: changing terms means #end! this one and .sign! a new
  # one. F16: at most one active subscription per institution (DB-backed
  # partial unique index, mirrored here for a friendlier error).
  class Subscription < ApplicationRecord
    self.table_name = "subscriptions"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :plan, class_name: "ControlPlane::Plan", optional: true
    has_many :institution_entitlements, class_name: "ControlPlane::Entitlement",
      foreign_key: :subscription_id, inverse_of: :subscription

    validates :plan_key, presence: true
    validates :base_price_per_student_cents, numericality: { greater_than_or_equal_to: 0 }
    validates :currency, presence: true, length: { is: 3 }
    validates :status, inclusion: { in: %w[active ended] }
    validates :starts_on, presence: true

    validate :ends_on_after_starts_on
    validate :single_active_subscription_per_institution, if: :active?

    scope :active, -> { where(status: "active") }
    scope :ended, -> { where(status: "ended") }

    def active? = status == "active"

    # Builds the immutable snapshot from the LIVE plan at signing time — the
    # only moment this reads the catalog. Nothing else re-reads it afterwards.
    def self.sign!(institution:, plan:, starts_on: Date.current)
      create!(
        institution: institution,
        plan: plan,
        plan_key: plan.key,
        base_price_per_student_cents: plan.base_price_per_student_cents,
        currency: plan.currency,
        price_tiers_snapshot: plan.price_tiers.order(:min_students).map do |tier|
          {
            "min_students" => tier.min_students,
            "max_students" => tier.max_students,
            "price_per_student_cents" => tier.price_per_student_cents
          }
        end,
        starts_on: starts_on,
        status: "active"
      )
    end

    def end!(ends_on: Date.current)
      update!(status: "ended", ends_on: ends_on)
    end

    def base_price_per_student = base_price_per_student_cents / 100.0

    private

    def ends_on_after_starts_on
      return if ends_on.nil? || starts_on.nil?
      errors.add(:ends_on, "debe ser posterior a la fecha de inicio") if ends_on <= starts_on
    end

    def single_active_subscription_per_institution
      scope = Subscription.active.where(institution_id: institution_id)
      scope = scope.where.not(id: id) if persisted?
      errors.add(:base, "esta institución ya tiene una suscripción activa") if scope.exists?
    end
  end
end
