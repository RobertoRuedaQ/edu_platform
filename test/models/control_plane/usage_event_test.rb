require "test_helper"

class ControlPlane::UsageEventTest < ActiveSupport::TestCase
  def build_institution
    slug = "ue-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_metered_addon
    ControlPlane::Addon.create!(key: "transportation", name: "Transporte", currency: "COP",
      metered: true, unit: "check-ins", included_quota: 100, overage_unit_price_cents: 10)
  end

  test "append-only: allows create but blocks update and destroy" do
    institution = build_institution
    addon = build_metered_addon
    event = ControlPlane::UsageEvent.create!(institution: institution, addon: addon, unit: "check-ins",
      quantity: 1, occurred_at: Time.current, idempotency_key: "k-1")

    assert event.persisted?
    assert event.readonly?

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(quantity: 2) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
  end

  test "idempotency_key must be unique per institution+addon" do
    institution = build_institution
    addon = build_metered_addon
    ControlPlane::UsageEvent.create!(institution: institution, addon: addon, unit: "check-ins",
      quantity: 1, occurred_at: Time.current, idempotency_key: "dup")

    duplicate = ControlPlane::UsageEvent.new(institution: institution, addon: addon, unit: "check-ins",
      quantity: 1, occurred_at: Time.current, idempotency_key: "dup")
    assert_not duplicate.valid?
  end

  test "the same idempotency_key is allowed across different addons" do
    institution = build_institution
    addon_a = build_metered_addon
    addon_b = ControlPlane::Addon.create!(key: "communication", name: "Comunicación", currency: "COP",
      metered: true, unit: "mensajes", included_quota: 100, overage_unit_price_cents: 5)

    ControlPlane::UsageEvent.create!(institution: institution, addon: addon_a, unit: "check-ins",
      quantity: 1, occurred_at: Time.current, idempotency_key: "shared-key")
    same_key_other_addon = ControlPlane::UsageEvent.new(institution: institution, addon: addon_b, unit: "mensajes",
      quantity: 1, occurred_at: Time.current, idempotency_key: "shared-key")

    assert same_key_other_addon.valid?
  end

  test "quantity must be positive" do
    institution = build_institution
    addon = build_metered_addon
    event = ControlPlane::UsageEvent.new(institution: institution, addon: addon, unit: "check-ins",
      quantity: 0, occurred_at: Time.current, idempotency_key: "k-zero")
    assert_not event.valid?
  end
end
