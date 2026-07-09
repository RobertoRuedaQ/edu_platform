class CreateUsageDailyRollups < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL, same posture as usage_events. Unlike usage_events, rollups ARE
    # recomputed (upsert) — re-running the rollup job for a given day updates
    # this row in place rather than accumulating duplicates (G4). S4's period
    # cutoff sums THESE rows, never usage_events directly.
    create_table :usage_daily_rollups, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :restrict }
      t.references :addon, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :addons, on_delete: :restrict }

      t.text :unit, null: false
      t.date :usage_date, null: false
      t.bigint :total_quantity, null: false, default: 0
      t.integer :event_count, null: false, default: 0
      t.timestamptz :rolled_up_at, null: false, default: -> { "now()" }

      t.timestamps
    end

    add_index :usage_daily_rollups, %i[institution_id addon_id unit usage_date], unique: true,
      name: "index_usage_daily_rollups_on_bucket"

    add_check_constraint :usage_daily_rollups, "total_quantity >= 0",
      name: "usage_daily_rollups_total_quantity_check"
    add_check_constraint :usage_daily_rollups, "event_count >= 0",
      name: "usage_daily_rollups_event_count_check"
  end
end
