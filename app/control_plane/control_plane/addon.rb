module ControlPlane
  # GLOBAL catalog row — 1 addon = 1 addon-able domain (F14). No RLS, no
  # institution_id: this is pure catalog, not tied to any tenant until S2's
  # institution_entitlements exists. Money is always cents (F6); #monthly_fee
  # is the only place cents becomes a display decimal, for the existing
  # `money(...)` view helper.
  class Addon < ApplicationRecord
    self.table_name = "addons"

    has_many :entitlements, class_name: "ControlPlane::Entitlement",
      foreign_key: :addon_id, inverse_of: :addon

    normalizes :key, with: ->(key) { key.to_s.strip.downcase }

    validates :key, presence: true, uniqueness: true,
      inclusion: { in: AddonCatalog::DOMAIN_KEYS, message: "no es un dominio addon-able válido" }
    validates :name, presence: true
    validates :currency, presence: true, length: { is: 3 }
    validates :status, inclusion: { in: %w[active retired] }
    validates :monthly_fee_cents, numericality: { greater_than_or_equal_to: 0 }

    validate :metering_fields_consistent

    scope :active, -> { where(status: "active") }
    scope :retired, -> { where(status: "retired") }

    def active? = status == "active"

    def retire!    = update!(status: "retired")
    def reactivate! = update!(status: "active")

    def monthly_fee = monthly_fee_cents / 100.0

    def overage_unit_price
      overage_unit_price_cents && overage_unit_price_cents / 100.0
    end

    private

    def metering_fields_consistent
      if metered?
        if included_quota.nil? || unit.blank? || overage_unit_price_cents.nil?
          errors.add(:base, "un addon medido requiere cupo incluido, unidad y precio de overage")
        end
      elsif included_quota.present? || unit.present? || overage_unit_price_cents.present?
        errors.add(:base, "un addon no medido no debe tener cupo, unidad ni precio de overage")
      end
    end
  end
end
