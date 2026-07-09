class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL, same posture as subscriptions/institution_entitlements/usage_*
    # (no RLS, no policy, no FORCE). institution_id/subscription_id are plain
    # FKs to global tables, never tenancy — S4's period cut never fixes a GUC.
    #
    # H8: draft -> finalized|void. The cut creates/regenerates a draft;
    # finalizing is a manual, audited platform_admin action. Finalizing is NOT
    # charging — there is no payment rail in v1.
    create_table :invoices, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :restrict }
      t.references :subscription, type: :uuid, null: true, index: true,
        foreign_key: { to_table: :subscriptions, on_delete: :nullify }

      t.date :period_start, null: false
      t.date :period_end, null: false

      t.text :currency, null: false
      t.text :status, null: false, default: "draft"
      t.bigint :subtotal_cents, null: false, default: 0
      t.text :notes

      t.timestamptz :finalized_at

      t.timestamps
    end

    # H1: at most one non-void invoice per (institution, period_start, period_end).
    # A void'd invoice for the same period doesn't block cutting a fresh one.
    add_index :invoices, %i[institution_id period_start period_end], unique: true,
      where: "status <> 'void'", name: "index_invoices_one_per_institution_and_period"

    add_check_constraint :invoices, "period_end >= period_start", name: "invoices_period_check"
    add_check_constraint :invoices, "char_length(currency) = 3", name: "invoices_currency_check"
    add_check_constraint :invoices, "status IN ('draft','finalized','void')", name: "invoices_status_check"
    add_check_constraint :invoices, "subtotal_cents >= 0", name: "invoices_subtotal_cents_check"
  end
end
