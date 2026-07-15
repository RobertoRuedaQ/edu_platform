module Assignments
  # A student's text answer to a published assignment — belongs to the
  # STUDENT regardless of who typed it (a minor with no login, B1, submits
  # through their guardian; submitted_by_user_id records that, never a
  # write-ownership boundary). One row per (assignment, student) —
  # last-write-wins, no revision history this slice. Deliberately no FK to
  # schedules::Assessment: submitting never creates a grade, grading never
  # requires a submission — two independent axes, paired only at read time
  # (Assignments::GradingView).
  class Submission < ApplicationRecord
    self.table_name = "submissions"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :assignment, class_name: "Assignments::Assignment"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :submitted_by_user, class_name: "Core::User", optional: true

    validates :body, presence: true
    validates :student_id, uniqueness: { scope: :assignment_id }

    # Calculated flag, never an enforcement — late submissions are always
    # accepted (§0/§5).
    def late?
      submitted_at.present? && submitted_at.to_date > assignment.due_date
    end
  end
end
