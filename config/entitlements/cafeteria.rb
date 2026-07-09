# Owned by app/domains/cafeteria. Addon-gated — mirrors
# config/navigation/cafeteria.rb's self-registration pattern. Drift against
# ControlPlane::AddonCatalog::DOMAIN_KEYS is caught by
# test/models/entitlement/registry_consistency_test.rb, not at runtime.
Entitlement::Registry.register("cafeteria")
