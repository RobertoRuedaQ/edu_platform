module Assignments
  # A text answer to a published assignment — belongs to a STUDENT (an
  # individual assignment) XOR a SubmissionGroup (a group assignment,
  # v1.23.0), never both/neither (real DB CHECK, same num_nonnulls pattern
  # as ConversationParticipant, v1.20.0). Belongs to the STUDENT/GROUP
  # regardless of who typed it — a minor with no login (B1) submits
  # through their guardian, and in a group ANY member may edit the shared
  # entrega; submitted_by_user_id records attribution only, never a
  # write-ownership boundary. One row per (assignment, student) or
  # (assignment, group) — last-write-wins, no revision history this slice.
  # Deliberately no FK to schedules::Assessment: submitting never creates a
  # grade, grading never requires a submission — two independent axes,
  # paired only at read time (Assignments::GradingView).
  class Submission < ApplicationRecord
    self.table_name = "submissions"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :assignment, class_name: "Assignments::Assignment"
    belongs_to :student, class_name: "GroupManagement::Student", optional: true
    belongs_to :submission_group, class_name: "Assignments::SubmissionGroup", optional: true
    belongs_to :submitted_by_user, class_name: "Core::User", optional: true
    has_many :submission_attachments, class_name: "Assignments::SubmissionAttachment",
      foreign_key: :submission_id, inverse_of: :submission, dependent: :destroy

    validates :body, presence: true
    validates :student_id, uniqueness: { scope: :assignment_id }, allow_nil: true
    validates :submission_group_id, uniqueness: { scope: :assignment_id }, allow_nil: true
    validate :exactly_one_identity

    # Calculated flag, never an enforcement — late submissions are always
    # accepted (§0/§5).
    def late?
      submitted_at.present? && submitted_at.to_date > assignment.due_date
    end

    private

    def exactly_one_identity
      return if [ student_id, submission_group_id ].compact.size == 1

      errors.add(:base, "debe pertenecer exactamente a un estudiante o a un grupo, nunca ambos ni ninguno")
    end
  end
end
