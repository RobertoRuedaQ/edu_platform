module Assignments
  # The evaluation itself (which level got marked per criterion) — domain
  # DATA, never the grade. Belongs to a student XOR a SubmissionGroup, same
  # num_nonnums CHECK pattern as Assignments::Submission (v1.23.0), mirroring
  # who the underlying entrega belongs to. schedules::Assessment stays the
  # ONLY place a score lives — Assignments::RubricGrader/GroupRubricGrader
  # compute a score from this row + the assignment's frozen rubric_snapshot,
  # then write it via GradeRecorder/GroupGrader exactly like a direct grade.
  class RubricEvaluation < ApplicationRecord
    self.table_name = "rubric_evaluations"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :assignment, class_name: "Assignments::Assignment"
    belongs_to :student, class_name: "GroupManagement::Student", optional: true
    belongs_to :submission_group, class_name: "Assignments::SubmissionGroup", optional: true
    belongs_to :evaluated_by, class_name: "Core::User", foreign_key: :evaluated_by_user_id, optional: true

    validates :student_id, uniqueness: { scope: :assignment_id }, allow_nil: true
    validates :submission_group_id, uniqueness: { scope: :assignment_id }, allow_nil: true
    validate :exactly_one_identity

    private

    def exactly_one_identity
      return if [ student_id, submission_group_id ].compact.size == 1

      errors.add(:base, "debe pertenecer exactamente a un estudiante o a un grupo, nunca ambos ni ninguno")
    end
  end
end
