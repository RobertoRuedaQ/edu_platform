class CreateInstitutionEntitlements < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL — same posture as subscriptions (no RLS, no policy, no FORCE).
    # institution_id/addon_id are FKs to GLOBAL tables, never a tenancy column.
    #
    # This is gate #1 of the two serial gates (§7.1): "can the INSTITUTION use
    # this addon?". Gate #2 (RBAC inside the tenant) is identity_access, S2b.
    #
    # Overrides are stored here but only CONSUMED in S4 billing — the
    # ControlPlane::Entitlements::Check predicate (S2a) ignores them entirely.
    create_table :institution_entitlements, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :cascade }
      t.references :addon, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :addons, on_delete: :restrict }
      t.references :subscription, type: :uuid, null: true, index: true,
        foreign_key: { to_table: :subscriptions, on_delete: :nullify }

      t.string :status, null: false, default: "active"

      t.date :valid_from, null: false, default: -> { "CURRENT_DATE" }
      t.date :valid_until

      # Negotiated overrides (nullable) — stored, not applied until S4.
      t.bigint :override_monthly_fee_cents
      t.bigint :override_included_quota
      t.bigint :override_unit_price_cents
      t.string :override_currency

      t.timestamps
    end

    # At most one active entitlement per institution+addon. Revoked rows are
    # kept as history (no hard-delete, ever).
    #
    # Hardening idea (documented, not built): a daterange(valid_from,
    # valid_until) column + GiST exclusion constraint per (institution_id,
    # addon_id) with WITHOUT OVERLAPS (native PG18, already used by
    # `schedules`) would forbid overlapping grant PERIODS at the DB level too.
    # The unique-partial-index below only forbids two simultaneously-active
    # rows; app-level validation covers periods for S2a.
    add_index :institution_entitlements, %i[institution_id addon_id], unique: true,
      where: "status = 'active'", name: "index_entitlements_one_active_per_institution_addon"

    add_check_constraint :institution_entitlements, "status IN ('active','revoked')",
      name: "institution_entitlements_status_check"
    add_check_constraint :institution_entitlements, "valid_until IS NULL OR valid_until > valid_from",
      name: "institution_entitlements_valid_until_check"
    add_check_constraint :institution_entitlements,
      "override_monthly_fee_cents IS NULL OR override_monthly_fee_cents >= 0",
      name: "institution_entitlements_override_monthly_fee_cents_check"
    add_check_constraint :institution_entitlements,
      "override_included_quota IS NULL OR override_included_quota >= 0",
      name: "institution_entitlements_override_included_quota_check"
    add_check_constraint :institution_entitlements,
      "override_unit_price_cents IS NULL OR override_unit_price_cents >= 0",
      name: "institution_entitlements_override_unit_price_cents_check"
    add_check_constraint :institution_entitlements,
      "override_currency IS NULL OR char_length(override_currency) = 3",
      name: "institution_entitlements_override_currency_check"
  end
end
