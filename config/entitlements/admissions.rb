# Owned by app/domains/admissions. Addon-gated — mirrors
# config/navigation/admissions.rb's self-registration pattern. Drift against
# ControlPlane::AddonCatalog::DOMAIN_KEYS is caught by
# test/models/entitlement/registry_consistency_test.rb, not at runtime.
Entitlement::Registry.register("admissions")
