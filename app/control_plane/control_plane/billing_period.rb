module ControlPlane
  # GLOBAL — same posture as invoices/subscriptions (no RLS, no policy, no
  # FORCE). A billing period is a distinct, addressable entity (not just two
  # loose date columns on invoices) so a manual payment can point at exactly
  # which period it settles, independent of how many invoices/re-cuts that
  # period has seen over time.
  class BillingPeriod < ApplicationRecord
    self.table_name = "billing_periods"

    belongs_to :institution, class_name: "Core::Institution"
    has_many :invoices, class_name: "ControlPlane::Invoice", dependent: :restrict_with_exception

    validates :starts_on, :ends_on, presence: true
    validate :ends_on_after_or_equal_starts_on

    private

    def ends_on_after_or_equal_starts_on
      return if starts_on.nil? || ends_on.nil?
      errors.add(:ends_on, "debe ser igual o posterior al inicio del periodo") if ends_on < starts_on
    end
  end
end
