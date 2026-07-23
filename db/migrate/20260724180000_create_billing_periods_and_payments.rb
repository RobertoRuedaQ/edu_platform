class CreateBillingPeriodsAndPayments < ActiveRecord::Migration[8.1]
  # up/down explícitos (no `change`) porque el backfill de invoices.billing_period_id
  # corre vía `execute` — no hay forma reversible automática de reconstruir eso.
  def up
    # GLOBAL — misma postura que invoices/subscriptions (sin RLS, sin FORCE,
    # FK plano a institutions). La unicidad de "un periodo no se repite"
    # (antes vivía en invoices) vive AQUÍ ahora.
    create_table :billing_periods, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :restrict }
      t.date :starts_on, null: false
      t.date :ends_on, null: false

      t.timestamps
    end

    add_index :billing_periods, %i[institution_id starts_on ends_on], unique: true,
      name: "index_billing_periods_on_institution_and_dates"
    add_check_constraint :billing_periods, "ends_on >= starts_on", name: "billing_periods_dates_check"

    add_reference :invoices, :billing_period, type: :uuid, null: true, index: true,
      foreign_key: { to_table: :billing_periods, on_delete: :restrict }

    # Backfill: un BillingPeriod por cada (institution_id, period_start, period_end)
    # distinto ya referenciado por alguna invoice existente (ninguna esperada en un
    # DB fresco, pero la migración queda segura si las hay).
    execute <<~SQL.squish
      INSERT INTO billing_periods (id, institution_id, starts_on, ends_on, created_at, updated_at)
      SELECT uuidv7(), institution_id, period_start, period_end, now(), now()
      FROM (SELECT DISTINCT institution_id, period_start, period_end FROM invoices) AS distinct_periods
    SQL

    execute <<~SQL.squish
      UPDATE invoices SET billing_period_id = billing_periods.id
      FROM billing_periods
      WHERE invoices.institution_id = billing_periods.institution_id
        AND invoices.period_start = billing_periods.starts_on
        AND invoices.period_end = billing_periods.ends_on
    SQL

    change_column_null :invoices, :billing_period_id, false

    remove_index :invoices, name: "index_invoices_one_per_institution_and_period"
    remove_check_constraint :invoices, name: "invoices_period_check"
    remove_column :invoices, :period_start
    remove_column :invoices, :period_end

    add_index :invoices, :billing_period_id, unique: true,
      where: "status <> 'void'", name: "index_invoices_one_per_billing_period"

    # prefijo control_plane_ porque `payments` YA es una tabla real de Finance
    # (tenant-scoped) — colisionaría.
    create_table :control_plane_payments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :restrict }
      t.references :invoice, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :invoices, on_delete: :restrict }
      t.bigint :amount_cents, null: false
      t.string :method, null: false
      t.date :paid_on, null: false
      t.text :notes
      t.references :recorded_by_platform_admin, type: :uuid, null: false,
        foreign_key: { to_table: :platform_admins, on_delete: :restrict }
      t.string :idempotency_key

      t.timestamps
    end

    add_index :control_plane_payments, %i[institution_id idempotency_key], unique: true,
      where: "idempotency_key IS NOT NULL", name: "index_control_plane_payments_on_institution_and_idempotency"
    add_check_constraint :control_plane_payments, "amount_cents > 0", name: "control_plane_payments_amount_cents_check"
    add_check_constraint :control_plane_payments, "method IN ('cash','card','transfer','other')",
      name: "control_plane_payments_method_check"
  end

  def down
    drop_table :control_plane_payments

    remove_index :invoices, name: "index_invoices_one_per_billing_period"

    add_column :invoices, :period_start, :date
    add_column :invoices, :period_end, :date

    execute <<~SQL.squish
      UPDATE invoices SET period_start = billing_periods.starts_on, period_end = billing_periods.ends_on
      FROM billing_periods
      WHERE invoices.billing_period_id = billing_periods.id
    SQL

    change_column_null :invoices, :period_start, false
    change_column_null :invoices, :period_end, false

    add_check_constraint :invoices, "period_end >= period_start", name: "invoices_period_check"
    add_index :invoices, %i[institution_id period_start period_end], unique: true,
      where: "status <> 'void'", name: "index_invoices_one_per_institution_and_period"

    remove_reference :invoices, :billing_period, foreign_key: true

    drop_table :billing_periods
  end
end
