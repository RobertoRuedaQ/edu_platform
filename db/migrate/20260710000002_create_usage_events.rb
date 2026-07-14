class CreateUsageEvents < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL, append-only (no updated_at — see ControlPlane::UsageEvent's
    # readonly? override). institution_id/addon_id are FKs to GLOBAL tables,
    # never tenancy columns — this pipe is domain-agnostic and never fixes a
    # tenant GUC (G6).
    #
    # G3: idempotency_key is NOT NULL — ingestion (ControlPlane::Usage::Ingest)
    # no-ops on a duplicate (institution, addon, idempotency_key) rather than
    # raising, so a caller that re-emits the same event is always safe.
    create_table :usage_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :restrict }
      t.references :addon, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :addons, on_delete: :restrict }

      # Frozen at event time — never re-reads Addon#unit later (M1 still open;
      # this column's value is an opaque string as far as S3a is concerned).
      t.text :unit, null: false
      t.bigint :quantity, null: false, default: 1
      t.timestamptz :occurred_at, null: false
      t.text :idempotency_key, null: false
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :usage_events, %i[institution_id addon_id idempotency_key], unique: true,
      name: "index_usage_events_on_idempotency"
    add_index :usage_events, %i[institution_id addon_id occurred_at],
      name: "index_usage_events_for_rollup"

    add_check_constraint :usage_events, "quantity > 0", name: "usage_events_quantity_check"
  end
end
