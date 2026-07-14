class CreateAddons < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL catalog — NOT tenant-owned, NOT RLS-scoped (like platform_admins).
    # Addon = domain 1:1 (F14: only the addon-able domains, never the
    # foundational ones). `key` is validated against
    # ControlPlane::AddonCatalog::DOMAIN_KEYS in the model, not here — the
    # canonical list lives in code, not in a DB enum/FK, because domains are
    # code, not rows.
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :addons, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.citext :key, null: false
      t.string :name, null: false
      t.text   :description

      # F6: money is always an integer in the minor unit, never a float.
      t.bigint :monthly_fee_cents, null: false, default: 0
      t.string :currency, null: false, default: "COP"

      t.boolean :metered, null: false, default: false
      t.bigint  :included_quota
      t.string  :unit
      t.bigint  :overage_unit_price_cents

      # F10: soft retirement, never hard-delete — historical invoices (S4)
      # will reference retired entries.
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :addons, :key, unique: true

    add_check_constraint :addons, "char_length(currency) = 3", name: "addons_currency_check"
    add_check_constraint :addons, "status IN ('active','retired')", name: "addons_status_check"
    add_check_constraint :addons, "monthly_fee_cents >= 0", name: "addons_monthly_fee_cents_check"
    add_check_constraint :addons, "included_quota IS NULL OR included_quota >= 0",
      name: "addons_included_quota_check"
    add_check_constraint :addons, "overage_unit_price_cents IS NULL OR overage_unit_price_cents >= 0",
      name: "addons_overage_unit_price_cents_check"

    # Exactly-one-of pattern for metering fields, mirroring the tenant's
    # conditional CHECKs: non-metered addons carry NO metering data,
    # metered addons carry ALL of it. App-level mirror in ControlPlane::Addon
    # gives a friendlier error; this is the backstop.
    add_check_constraint :addons, <<~SQL.squish, name: "addons_metering_consistency_check"
      (metered = false AND included_quota IS NULL AND unit IS NULL AND overage_unit_price_cents IS NULL)
      OR
      (metered = true AND included_quota IS NOT NULL AND unit IS NOT NULL AND overage_unit_price_cents IS NOT NULL)
    SQL
  end
end
