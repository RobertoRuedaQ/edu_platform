require "test_helper"

class ControlPlane::Usage::IngestTest < ActiveSupport::TestCase
  def build_institution
    slug = "ing-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_metered_addon(key: "transportation")
    ControlPlane::Addon.create!(key: key, name: key.humanize, currency: "COP",
      metered: true, unit: "check-ins", included_quota: 100, overage_unit_price_cents: 10)
  end

  test "creates a usage_event, freezing the unit" do
    institution = build_institution
    addon = build_metered_addon

    event = ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation",
      unit: "check-ins", occurred_at: Time.current, idempotency_key: "e-1")

    assert event.persisted?
    assert_equal "check-ins", event.unit
  end

  test "the same idempotency_key twice is a no-op, not a second event" do
    institution = build_institution
    build_metered_addon

    first = ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation",
      unit: "check-ins", occurred_at: Time.current, idempotency_key: "same-key")
    second = ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation",
      unit: "check-ins", occurred_at: Time.current, idempotency_key: "same-key")

    assert_equal first.id, second.id
    assert_equal 1, ControlPlane::UsageEvent.where(institution_id: institution.id).count
  end

  test "rejects an addon that is not metered" do
    institution = build_institution
    ControlPlane::Addon.create!(key: "counseling", name: "Consejería", currency: "COP")

    assert_raises(ControlPlane::Usage::Ingest::Rejected) do
      ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "counseling",
        unit: "casos", occurred_at: Time.current, idempotency_key: "bad-1")
    end
    assert_equal 0, ControlPlane::UsageEvent.count
  end

  test "rejects an unknown addon key" do
    institution = build_institution

    assert_raises(ControlPlane::Usage::Ingest::Rejected) do
      ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "does_not_exist",
        unit: "x", occurred_at: Time.current, idempotency_key: "bad-2")
    end
  end

  test "does not require an active entitlement (usage is a fact, not gated)" do
    institution = build_institution
    build_metered_addon
    # No ControlPlane::Entitlement created at all for this institution+addon.

    event = ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation",
      unit: "check-ins", occurred_at: Time.current, idempotency_key: "no-entitlement")
    assert event.persisted?
  end

  test ".emit is the same as .call when the addon is metered" do
    institution = build_institution
    build_metered_addon

    event = ControlPlane::Usage::Ingest.emit(institution: institution, addon_key: "transportation",
      unit: "check-ins", occurred_at: Time.current, idempotency_key: "emit-1")
    assert event.persisted?
  end

  test ".emit swallows Rejected (unknown/unmetered addon) instead of raising, for domain call sites" do
    institution = build_institution

    assert_nil ControlPlane::Usage::Ingest.emit(institution: institution, addon_key: "does_not_exist",
      unit: "x", occurred_at: Time.current, idempotency_key: "emit-2")
    assert_equal 0, ControlPlane::UsageEvent.count
  end

  test "runs with no tenant GUC set at all" do
    institution = build_institution
    build_metered_addon

    assert_nil ActiveRecord::Base.uncached {
      ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_institution_id', true)").presence
    }

    ControlPlane::Usage::Ingest.call(institution: institution, addon_key: "transportation",
      unit: "check-ins", occurred_at: Time.current, idempotency_key: "no-guc")

    assert_nil ActiveRecord::Base.uncached {
      ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_institution_id', true)").presence
    }
  end
end
