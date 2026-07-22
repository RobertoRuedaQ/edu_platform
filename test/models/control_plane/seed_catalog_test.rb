require "test_helper"

# S3b (v1.30.0) + OPEN_PROCESS.md item #5 (cafeteria/transportation, this
# slice): SeedCatalog is the demo catalog seed (S1) — this file only covers
# what metering slices changed (metered flags/units), not the whole seed.
class ControlPlane::SeedCatalogTest < ActiveSupport::TestCase
  test "the eight metered domains are metered with their real facturable unit" do
    ControlPlane::SeedCatalog.call

    expected = {
      "communication" => "mensajes",
      "attendance" => "registros",
      "report_cards" => "boletines",
      "assignments" => "entregas",
      "extracurriculars" => "inscripciones",
      "finance" => "transacciones",
      "cafeteria" => "compras",
      "transportation" => "abordajes"
    }
    expected.each do |key, unit|
      addon = ControlPlane::Addon.find_by!(key: key)
      assert addon.metered?, "#{key} should be metered"
      assert_equal unit, addon.unit
      assert_not_nil addon.included_quota
      assert_not_nil addon.overage_unit_price_cents
    end
  end

  test "the remaining Clase C / no-clear-event domains stay unmetered (OPEN_PROCESS.md item #5)" do
    ControlPlane::SeedCatalog.call

    %w[schedules student_support counseling analytics_bi].each do |key|
      addon = ControlPlane::Addon.find_by!(key: key)
      assert_not addon.metered?, "#{key} should stay unmetered"
      assert_nil addon.unit
    end
  end

  test "is idempotent — running it twice never duplicates addons" do
    ControlPlane::SeedCatalog.call
    ControlPlane::SeedCatalog.call

    assert_equal ControlPlane::SeedCatalog::ADDONS.size, ControlPlane::Addon.count
  end
end
