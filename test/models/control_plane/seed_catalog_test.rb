require "test_helper"

# S3b (v1.30.0): SeedCatalog is the demo catalog seed (S1) — this file only
# covers what THIS slice changed (metered flags/units), not the whole seed.
class ControlPlane::SeedCatalogTest < ActiveSupport::TestCase
  test "transportation is unmetered (Clase C, no real event to measure — see OPEN_PROCESS.md guardrail v1.30.0)" do
    ControlPlane::SeedCatalog.call
    transportation = ControlPlane::Addon.find_by!(key: "transportation")
    assert_not transportation.metered?
    assert_nil transportation.unit
  end

  test "the six S3b domains are metered with their real facturable unit" do
    ControlPlane::SeedCatalog.call

    expected = {
      "communication" => "mensajes",
      "attendance" => "registros",
      "report_cards" => "boletines",
      "assignments" => "entregas",
      "extracurriculars" => "inscripciones",
      "finance" => "transacciones"
    }
    expected.each do |key, unit|
      addon = ControlPlane::Addon.find_by!(key: key)
      assert addon.metered?, "#{key} should be metered"
      assert_equal unit, addon.unit
      assert_not_nil addon.included_quota
      assert_not_nil addon.overage_unit_price_cents
    end
  end

  test "is idempotent — running it twice never duplicates addons" do
    ControlPlane::SeedCatalog.call
    ControlPlane::SeedCatalog.call

    assert_equal ControlPlane::SeedCatalog::ADDONS.size, ControlPlane::Addon.count
  end
end
