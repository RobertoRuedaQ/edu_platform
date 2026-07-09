class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL — same posture as addons/plans (no RLS, no policy, no FORCE).
    # institution_id is a FK to the GLOBAL institutions table, NOT a tenancy
    # column: this table is never scoped by app.current_institution_id.
    #
    # F15: the plan's tarifa is frozen as an immutable snapshot at signing time
    # (plan_key/base_price_per_student_cents/currency scalars + price_tiers_snapshot
    # jsonb). plan_id is provenance only (nullable, nullified on plan deletion) —
    # editing the live plan afterwards must never change an existing subscription.
    create_table :subscriptions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :restrict }
      t.references :plan, type: :uuid, null: true, index: true,
        foreign_key: { to_table: :plans, on_delete: :nullify }

      t.string :plan_key, null: false
      t.bigint :base_price_per_student_cents, null: false
      t.string :currency, null: false, default: "COP"
      t.jsonb  :price_tiers_snapshot, null: false, default: []

      t.string :status, null: false, default: "active"

      t.date :starts_on, null: false
      t.date :ends_on

      t.datetime :signed_at, null: false, default: -> { "now()" }

      t.timestamps
    end

    # At most one active subscription per institution.
    add_index :subscriptions, :institution_id, unique: true,
      where: "status = 'active'", name: "index_subscriptions_one_active_per_institution"

    add_check_constraint :subscriptions, "status IN ('active','ended')", name: "subscriptions_status_check"
    add_check_constraint :subscriptions, "char_length(currency) = 3", name: "subscriptions_currency_check"
    add_check_constraint :subscriptions, "base_price_per_student_cents >= 0",
      name: "subscriptions_base_price_per_student_cents_check"
    add_check_constraint :subscriptions, "ends_on IS NULL OR ends_on > starts_on",
      name: "subscriptions_ends_on_check"
  end
end
