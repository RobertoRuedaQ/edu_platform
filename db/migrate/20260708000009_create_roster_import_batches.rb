class CreateRosterImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_import_batches, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.string :kind, null: false            # students | guardians
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.string :status, null: false, default: "uploaded"
      t.jsonb  :summary, null: false, default: {}

      t.references :created_by, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }

      t.timestamps
    end

    add_index :roster_import_batches, %i[institution_id academic_term_id],
      name: "index_roster_import_batches_on_institution_and_term"

    add_check_constraint :roster_import_batches, "kind IN ('students','guardians')",
      name: "roster_import_batches_kind_check"
    add_check_constraint :roster_import_batches,
      "status IN ('uploaded','validated','previewed','committed','failed')",
      name: "roster_import_batches_status_check"

    enable_rls :roster_import_batches
  end
end
