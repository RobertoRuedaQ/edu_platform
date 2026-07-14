class CreateInvoiceLineItems < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL, same posture as invoices. addon_id is a plain FK to the global
    # addons table, never tenancy — null for base_seats, present for the
    # other two kinds (CHECK below).
    #
    # Append-only once created (see ControlPlane::InvoiceLineItem#readonly?) —
    # PeriodCut's idempotent re-cut deletes and recreates a DRAFT's lines, it
    # never edits one in place. amount_cents is frozen at cut time
    # (quantity * unit_price_cents), never recomputed live.
    create_table :invoice_line_items, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :invoice, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :invoices, on_delete: :cascade }
      t.references :addon, type: :uuid, null: true, index: true,
        foreign_key: { to_table: :addons, on_delete: :restrict }

      t.text :kind, null: false
      t.text :description, null: false
      t.decimal :quantity, null: false
      t.bigint :unit_price_cents, null: false
      t.bigint :amount_cents, null: false

      # Provenance for a defensible invoice: which snapshot/rollups/entitlement
      # (and whether an override applied) produced this line.
      t.jsonb :source_ref, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_check_constraint :invoice_line_items, "kind IN ('base_seats','addon_fee','usage_overage')",
      name: "invoice_line_items_kind_check"
    add_check_constraint :invoice_line_items, "quantity >= 0", name: "invoice_line_items_quantity_check"
    add_check_constraint :invoice_line_items, "unit_price_cents >= 0",
      name: "invoice_line_items_unit_price_cents_check"
    add_check_constraint :invoice_line_items, <<~SQL.squish, name: "invoice_line_items_addon_coherence_check"
      (kind = 'base_seats' AND addon_id IS NULL)
      OR
      (kind IN ('addon_fee','usage_overage') AND addon_id IS NOT NULL)
    SQL
  end
end
