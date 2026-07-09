require "test_helper"

class ControlPlane::Usage::RollupJobTest < ActiveSupport::TestCase
  def build_institution
    slug = "roll-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_metered_addon
    ControlPlane::Addon.create!(key: "transportation", name: "Transporte", currency: "COP",
      metered: true, unit: "check-ins", included_quota: 100, overage_unit_price_cents: 10)
  end

  test "aggregates the day's events into total_quantity and event_count" do
    institution = build_institution
    addon = build_metered_addon
    today = Date.current

    ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation", unit: "check-ins",
      occurred_at: today.noon, idempotency_key: "a", quantity: 3)
    ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation", unit: "check-ins",
      occurred_at: today.noon + 1.hour, idempotency_key: "b", quantity: 5)

    ControlPlane::Usage::RollupJob.perform_now(today)

    rollup = ControlPlane::UsageDailyRollup.find_by(institution_id: institution.id, addon_id: addon.id,
      unit: "check-ins", usage_date: today)
    assert_equal 8, rollup.total_quantity
    assert_equal 2, rollup.event_count
  end

  test "re-running for the same day is idempotent — no duplicate row, no double count" do
    institution = build_institution
    build_metered_addon
    today = Date.current

    ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation", unit: "check-ins",
      occurred_at: today.noon, idempotency_key: "x", quantity: 10)

    ControlPlane::Usage::RollupJob.perform_now(today)
    ControlPlane::Usage::RollupJob.perform_now(today)
    ControlPlane::Usage::RollupJob.perform_now(today)

    rollups = ControlPlane::UsageDailyRollup.where(institution_id: institution.id, usage_date: today)
    assert_equal 1, rollups.count
    assert_equal 10, rollups.first.total_quantity
  end

  test "does not touch events from other days" do
    institution = build_institution
    build_metered_addon

    ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation", unit: "check-ins",
      occurred_at: 2.days.ago, idempotency_key: "old", quantity: 99)
    ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation", unit: "check-ins",
      occurred_at: Time.current, idempotency_key: "today", quantity: 1)

    ControlPlane::Usage::RollupJob.perform_now(Date.current)

    assert_equal 0, ControlPlane::UsageDailyRollup.where(usage_date: 2.days.ago.to_date).count
    today_rollup = ControlPlane::UsageDailyRollup.find_by(institution_id: institution.id, usage_date: Date.current)
    assert_equal 1, today_rollup.total_quantity
  end

  test "runs with no tenant GUC set at all" do
    institution = build_institution
    build_metered_addon
    ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation", unit: "check-ins",
      occurred_at: Time.current, idempotency_key: "guc-check", quantity: 1)

    ControlPlane::Usage::RollupJob.perform_now(Date.current)

    assert_nil ActiveRecord::Base.uncached {
      ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_institution_id', true)").presence
    }
  end
end
