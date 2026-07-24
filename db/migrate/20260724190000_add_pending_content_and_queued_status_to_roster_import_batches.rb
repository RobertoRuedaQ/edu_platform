class AddPendingContentAndQueuedStatusToRosterImportBatches < ActiveRecord::Migration[8.1]
  def up
    add_column :roster_import_batches, :pending_content, :text

    remove_check_constraint :roster_import_batches, name: "roster_import_batches_status_check"
    add_check_constraint :roster_import_batches,
      "status IN ('queued','uploaded','validated','previewed','committed','failed')",
      name: "roster_import_batches_status_check"
  end

  def down
    remove_check_constraint :roster_import_batches, name: "roster_import_batches_status_check"
    add_check_constraint :roster_import_batches,
      "status IN ('uploaded','validated','previewed','committed','failed')",
      name: "roster_import_batches_status_check"

    remove_column :roster_import_batches, :pending_content
  end
end
