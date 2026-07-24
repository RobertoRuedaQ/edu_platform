module Core
  # One roster upload (students or guardians) tied to an academic term. Parsed
  # lines live in RosterImportRow.
  #
  # The raw uploaded file is never persisted UNENCRYPTED, and never for
  # longer than one parse attempt (privacy — RosterImport slice, J6/full-async
  # hardening). While the batch sits in `queued` status, its content lives
  # ONLY in `pending_content` below (encrypted); ParseAndValidateJob clears it
  # the moment Parser has read it. Still deliberately NOT has_one_attached
  # :file — active_storage_blobs/attachments are GLOBAL tables with no RLS,
  # so attaching a tenant's CSV there would be an actual cross-tenant
  # exposure of sensitive data (national_id and similar), not just a style
  # preference. Same reasoning rules out passing the content as a Solid
  # Queue job argument (solid_queue_jobs is just as global/RLS-less) — the
  # job only ever receives this row's own id, and `pending_content` stays
  # inside THIS table, which already has RLS (see the original migration).
  class RosterImportBatch < ApplicationRecord
    self.table_name = "roster_import_batches"

    # Non-deterministic (unlike Core::User/GroupManagement::Student's
    # national_id): nothing ever looks this up by value, it only needs to be
    # unreadable at rest for the short window between upload and the job
    # clearing it.
    encrypts :pending_content

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :created_by, class_name: "Core::InstitutionUser", optional: true

    has_many :roster_import_rows, class_name: "Core::RosterImportRow",
             dependent: :destroy
  end
end
