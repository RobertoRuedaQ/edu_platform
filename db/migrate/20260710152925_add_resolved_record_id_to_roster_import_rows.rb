class AddResolvedRecordIdToRosterImportRows < ActiveRecord::Migration[8.1]
  def change
    # Links a committed row to the GroupManagement::Student it created/updated.
    # No FK: this slice only ever points at students, but the guardians slice
    # (next) will point the same column at a different table, so this stays a
    # plain uuid rather than a table-specific reference.
    add_column :roster_import_rows, :resolved_record_id, :uuid
  end
end
