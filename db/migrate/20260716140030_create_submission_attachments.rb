class CreateSubmissionAttachments < ActiveRecord::Migration[8.1]
  # assignments (v1.24.0, slice 3: entrega — file attachments). Active
  # Storage's own tables (active_storage_blobs/attachments/variant_records)
  # already existed in this repo since the first commit but were never used
  # (see Core::RosterImportBatch's docstring: those tables are GLOBAL, with
  # no institution_id and no RLS — attaching straight to them would be an
  # actual cross-tenant exposure, not a style preference).
  #
  # This bridge table is the tenant boundary INSTEAD: RLS ENABLE+FORCE here,
  # same as every other tenant-owned table — a blob is only ever reachable
  # by first resolving ITS row, which RLS already scopes. The raw AS tables
  # stay exactly as Rails ships them; never add RLS there (see
  # PROCESO_ABIERTO.md's guardrail — a future recon must not "fix" this).
  def change
    create_table :submission_attachments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :submission, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :submissions, on_delete: :cascade }
      # Attribution only (nullable + nullify, same convention as
      # submissions.submitted_by_user_id) — who uploaded it, never who the
      # work belongs to (that's the submission's student/group).
      t.references :attached_by_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end
    add_index :submission_attachments, %i[institution_id submission_id],
      name: "idx_submission_attachments_on_institution_submission"

    enable_rls :submission_attachments
  end
end
