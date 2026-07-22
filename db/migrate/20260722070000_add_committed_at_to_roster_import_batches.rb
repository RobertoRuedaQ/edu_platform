class AddCommittedAtToRosterImportBatches < ActiveRecord::Migration[8.1]
  # guidelines/OPEN_PROCESS.md item #2 (onboarding hardening — purga de
  # roster_import_rows post-commit, gated closed 2026-07-22): the retention
  # sweep (Core::RosterImport::RowPurger) needs an explicit "when did this
  # batch actually commit" timestamp — `updated_at` would be an implicit,
  # fragile proxy (anything else that ever touches the batch row would move
  # it), so this is a dedicated column set exactly once, by Committer, at the
  # moment `status` flips to "committed".
  def change
    add_column :roster_import_batches, :committed_at, :datetime
  end
end
