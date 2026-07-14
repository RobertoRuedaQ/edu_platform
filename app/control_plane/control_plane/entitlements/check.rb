module ControlPlane
  module Entitlements
    # The predicate half of gate #1 (§7.1): "does INSTITUTION have ADDON_KEY
    # active right now?" — a plain boolean, no Current, no GUC, no tenant
    # scoping. Deliberately ignores ControlPlane::Entitlement overrides (S4
    # concern) and Addon#status (an addon retired mid-grant is an
    # F10-bis / S1 concern, not this predicate's).
    #
    # S2b (out of scope here) will wire Current.institution.entitled?(:x)
    # around this and will treat the FOUNDATIONAL domains (core,
    # teacher_management, group_management, identity_access) as always
    # entitled WITHOUT calling Check at all — Check only ever answers for
    # addon-able domains (ControlPlane::AddonCatalog::DOMAIN_KEYS).
    module Check
      module_function

      def entitled?(institution:, addon_key:, at: Time.current)
        addon = ControlPlane::Addon.find_by(key: addon_key.to_s)
        return false if addon.nil?

        date = at.to_date
        ControlPlane::Entitlement.active
          .where(institution_id: institution.id, addon_id: addon.id)
          .where("valid_from <= ?", date)
          .where("valid_until IS NULL OR valid_until > ?", date)
          .exists?
      end
    end
  end
end
