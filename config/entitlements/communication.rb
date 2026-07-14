# Owned by app/domains/communication. Addon-gated — see
# config/entitlements/cafeteria.rb for the pattern this mirrors. No
# Communication:: namespace exists yet (still stub per PROJECT_STATE.md §8);
# this declaration pre-registers the gate for the day it's built.
Entitlement::Registry.register("communication")
