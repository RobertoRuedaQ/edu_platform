module ControlPlane
  # GLOBAL — one institution × addon grant (table institution_entitlements;
  # class named Entitlement, not InstitutionEntitlement, matching the naming
  # the pre-existing stub screens already anticipated). institution_id/addon_id
  # are plain FKs to global tables, never RLS scope.
  #
  # This is GATE #1 of the two serial gates (§7.1): "can the INSTITUTION use
  # this addon?" Gate #2 (RBAC inside the tenant) is identity_access — S2b,
  # out of scope here.
  #
  # Overrides are stored (for S4 billing) but deliberately IGNORED by
  # ControlPlane::Entitlements::Check — see that file.
  class Entitlement < ApplicationRecord
    self.table_name = "institution_entitlements"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :addon, class_name: "ControlPlane::Addon"
    belongs_to :subscription, class_name: "ControlPlane::Subscription", optional: true

    validates :status, inclusion: { in: %w[active revoked] }
    validates :valid_from, presence: true
    validates :override_monthly_fee_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :override_included_quota, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :override_unit_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :override_currency, length: { is: 3 }, allow_nil: true

    validate :valid_until_after_valid_from
    validate :single_active_entitlement_per_institution_addon, if: :active?

    scope :active, -> { where(status: "active") }
    scope :revoked, -> { where(status: "revoked") }

    def active? = status == "active"

    def revoke!     = update!(status: "revoked")
    def reactivate! = update!(status: "active")

    def active_on?(date = Date.current)
      active? && valid_from <= date && (valid_until.nil? || valid_until > date)
    end

    def negotiated?
      override_monthly_fee_cents.present? || override_included_quota.present? || override_unit_price_cents.present?
    end

    private

    def valid_until_after_valid_from
      return if valid_until.nil? || valid_from.nil?
      errors.add(:valid_until, "debe ser posterior a la fecha de inicio") if valid_until <= valid_from
    end

    def single_active_entitlement_per_institution_addon
      scope = Entitlement.active.where(institution_id: institution_id, addon_id: addon_id)
      scope = scope.where.not(id: id) if persisted?
      errors.add(:base, "ya existe un entitlement activo de este addon para esta institución") if scope.exists?
    end
  end
end
