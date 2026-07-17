# Owned by app/domains/extracurriculars. Addon-gated — mismo patrón que
# config/entitlements/attendance.rb. Debe existir su gemelo en
# ControlPlane::AddonCatalog::DOMAIN_KEYS (cruzado por
# test/models/entitlement/registry_consistency_test.rb).
Entitlement::Registry.register("extracurriculars")
