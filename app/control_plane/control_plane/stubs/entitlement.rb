# frozen_string_literal: true

module ControlPlane
  module Stubs
    # One institution × addon grant. This is the FIRST of the two serial gates:
    #   1. entitlement  — can the INSTITUTION use this addon? (this record)
    #   2. RBAC (identity_access) — can the USER inside do the action?
    # Only gate #1 lives in the control plane; gate #2 is a tenant concern.
    #
    # `valid_from`/`valid_until` date the grant. A negotiated override may pin a
    # custom fee and/or quota that beats the plan default.
    #
    # TODO: reemplazar por modelo real (ControlPlane::Entitlement).
    Entitlement = Data.define(
      :institution_name,
      :addon_key,
      :addon_name,
      :enabled,
      :valid_from,
      :valid_until,       # nil = open-ended
      :override_fee,      # nil = use plan/addon default
      :override_quota,    # nil = use plan/addon default
      :currency
    ) do
      def enabled? = enabled
      def negotiated? = !override_fee.nil? || !override_quota.nil?
    end
  end
end
