# frozen_string_literal: true

module ControlPlane
  module Stubs
    # A platform addon in the catalog. Decision: Addon = domain 1:1 (there is no
    # addon_features table yet), so `domain` names the bounded context it unlocks.
    #
    # `metered` addons bill overage by EVENTS (never students): `unit` labels the
    # event and `quota` is the included allowance before overage kicks in.
    #
    # TODO: reemplazar por modelo real (ControlPlane::Addon).
    Addon = Data.define(
      :key,          # stable slug, matches the domain namespace
      :name,         # human label (es)
      :domain,       # app/domains/<domain> unlocked by this addon
      :status,       # "available" | "beta" | "deprecated"
      :monthly_fee,  # flat per-institution fee (addon_fee line kind)
      :currency,
      :metered,      # bills usage overage?
      :unit,         # event unit label when metered (e.g. "transacciones")
      :quota         # included events/month before overage; nil = unlimited
    ) do
      def metered? = metered
      def available? = status.to_s == "available"
    end
  end
end
