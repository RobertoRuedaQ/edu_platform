module Assignments
  # A file the TEACHER attaches to the Assignment itself (v1.25.0) —
  # instructions/resources, docx/pdf/jpg/png — as opposed to
  # Assignments::SubmissionAttachment (v1.24.0), which is what a
  # student/guardian attaches to their OWN entrega. Same bridge-table
  # shape and same tenant boundary reasoning (RLS FORCE here; Active
  # Storage's own tables have no institution_id/RLS at all — see
  # SubmissionAttachment's docstring and OPEN_PROCESS.md's guardrail), but
  # the write gate is RBAC (assignment.manage), never a portal relation —
  # this is the teacher's own resource, not a student/guardian write.
  class Material < ApplicationRecord
    self.table_name = "assignment_materials"

    DOCX_CONTENT_TYPE = Assignments::AttachmentTypeCheck::DOCX_CONTENT_TYPE
    ALLOWED_CONTENT_TYPES = Assignments::AttachmentTypeCheck::ALLOWED_CONTENT_TYPES

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :assignment, class_name: "Assignments::Assignment"
    belongs_to :attached_by, class_name: "Core::User", foreign_key: :attached_by_user_id, optional: true
    has_one_attached :file

    # docx never renders in a browser — download only. pdf/jpg/png preview
    # inline, same rule as SubmissionAttachment (§5).
    def disposition
      file.content_type == DOCX_CONTENT_TYPE ? "attachment" : "inline"
    end
  end
end
