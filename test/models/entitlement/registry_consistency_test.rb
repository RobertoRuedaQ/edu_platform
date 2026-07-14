require "test_helper"

class Entitlement::RegistryConsistencyTest < ActiveSupport::TestCase
  # The ONE place tenant-side gating and the control plane's catalog are
  # allowed to know about each other. If this fails, either a domain was
  # gated (config/entitlements/*.rb) without a matching addon in
  # ControlPlane::AddonCatalog::DOMAIN_KEYS, or an addon was added to the
  # catalog without gating its domain here — both are a silent security gap.
  test "gated domains match the control plane's addon-able catalog exactly" do
    assert_equal ControlPlane::AddonCatalog::DOMAIN_KEYS.sort, Entitlement::Registry.domains.sort
  end

  test "no foundational domain is ever declared gated" do
    foundational = %w[core teacher_management group_management identity_access]
    assert_empty foundational & Entitlement::Registry.domains
  end

  test "EntitledAddonKeys fails closed to an empty set with no institution" do
    assert_equal Set.new, Core::Access::EntitledAddonKeys.for(nil)
  end
end
