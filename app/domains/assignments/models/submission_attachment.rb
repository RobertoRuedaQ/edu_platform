module Assignments
  # A file attached to an existing Submission (v1.24.0) — docx/pdf/jpg/png,
  # validated by Assignments::AttachmentAdder (real content-type via Active
  # Storage's Marcel-based detection, never the filename extension). The
  # tenant boundary is THIS row (RLS FORCE) — the underlying
  # active_storage_blobs/attachments rows have no institution_id and no
  # RLS at all (Rails' own tables, deliberately left alone; see the
  # migration's comment and PROCESO_ABIERTO.md's guardrail). A blob is only
  # ever reachable by first resolving one of these rows, which RLS already
  # scopes — never through Active Storage's own signed routes
  # (rails_blob_path and friends), which bypass this entirely.
  class SubmissionAttachment < ApplicationRecord
    self.table_name = "submission_attachments"

    DOCX_CONTENT_TYPE = Assignments::AttachmentTypeCheck::DOCX_CONTENT_TYPE
    ALLOWED_CONTENT_TYPES = Assignments::AttachmentTypeCheck::ALLOWED_CONTENT_TYPES

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :submission, class_name: "Assignments::Submission"
    belongs_to :attached_by, class_name: "Core::User", foreign_key: :attached_by_user_id, optional: true
    has_one_attached :file

    # docx never renders in a browser — download only. pdf/jpg/png preview
    # inline in both the submission and review views (§6).
    def disposition
      file.content_type == DOCX_CONTENT_TYPE ? "attachment" : "inline"
    end
  end
end
