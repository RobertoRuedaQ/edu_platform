class CreateRosterImportRows < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_import_rows, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :roster_import_batch, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.integer :line_number, null: false
      t.jsonb   :raw, null: false
      # Nullable: rows are inserted first, then classified during validation.
      # The CHECK only constrains non-null values.
      t.string  :status
      t.string  :message

      t.timestamps
    end

    add_index :roster_import_rows, %i[institution_id roster_import_batch_id],
      name: "index_roster_import_rows_on_institution_and_batch"

    add_check_constraint :roster_import_rows,
      "status IN ('valid','error','duplicate','collision')",
      name: "roster_import_rows_status_check"

    enable_rls :roster_import_rows
  end
end
