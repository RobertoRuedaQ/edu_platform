module Core
  # One roster upload (students or guardians) tied to an academic term. Parsed
  # lines live in RosterImportRow.
  #
  # The raw uploaded file is NEVER persisted (privacy — RosterImport slice,
  # J6): it's parsed in memory during the upload request and discarded.
  # deliberately NOT has_one_attached :file — active_storage_blobs/
  # attachments are GLOBAL tables with no RLS, so attaching a tenant's CSV
  # there would be an actual cross-tenant exposure of sensitive data
  # (national_id and similar), not just a style preference.
  class RosterImportBatch < ApplicationRecord
    self.table_name = "roster_import_batches"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :created_by, class_name: "Core::InstitutionUser", optional: true

    has_many :roster_import_rows, class_name: "Core::RosterImportRow",
             dependent: :destroy
  end
end
