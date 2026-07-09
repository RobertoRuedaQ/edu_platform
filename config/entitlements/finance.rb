# Owned by app/domains/finance. Addon-gated — see
# config/entitlements/cafeteria.rb for the pattern this mirrors. No
# Finance::*Controller exists yet (models-only domain as of this slice); this
# declaration pre-registers the gate so it applies automatically the day a
# controller under Finance:: is built, with no further entitlement wiring.
Entitlement::Registry.register("finance")
