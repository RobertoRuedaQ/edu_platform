module Core
  module Access
    # Builds the Set of addon keys CURRENTLY entitled for one institution —
    # the per-request memo lives on Current (see app/models/current.rb), this
    # is just the query behind it. Only ever checks the domains
    # Entitlement::Registry declares gated (tenant-side list); never touches
    # ControlPlane::AddonCatalog::DOMAIN_KEYS directly (see that registry's
    # header for why). Delegates the actual predicate to
    # Core::Institution#entitled? — no entitlement logic duplicated here.
    module EntitledAddonKeys
      module_function

      def for(institution)
        return Set.new if institution.nil?

        ::Entitlement::Registry.domains.select { |key| institution.entitled?(key) }.to_set
      end
    end
  end
end
