module Core
  # A single parsed line from a RosterImportBatch upload, with its validation
  # status and any error/collision message.
  class RosterImportRow < ApplicationRecord
    self.table_name = "roster_import_rows"

    # institution_id is required for RLS; declared here so it is set/validated
    # on insert (the row can't inherit it implicitly from the batch).
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :roster_import_batch, class_name: "Core::RosterImportBatch"
  end
end
