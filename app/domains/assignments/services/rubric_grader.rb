module Assignments
  # Grading ONE student by rubric — computes the score from the
  # assignment's frozen rubric_snapshot (Assignments::RubricScore), persists
  # the evaluation itself (which level per criterion — domain DATA, upserted
  # so re-grading never duplicates), then writes the score through
  # Assignments::GradeRecorder exactly like a direct grade. The rubric
  # NEVER stores the grade itself — schedules::Assessment stays the one
  # gradebook.
  class RubricGrader
    Result = Data.define(:evaluation, :assessment, :error)

    def self.call(assignment:, student:, levels_by_criterion:, evaluated_by:)
      new(assignment: assignment, student: student, levels_by_criterion: levels_by_criterion,
        evaluated_by: evaluated_by).call
    end

    def initialize(assignment:, student:, levels_by_criterion:, evaluated_by:)
      @assignment = assignment
      @student = student
      @levels_by_criterion = levels_by_criterion
      @evaluated_by = evaluated_by
    end

    def call
      scored = Assignments::RubricScore.call(snapshot: assignment.rubric_snapshot, levels_by_criterion: levels_by_criterion)
      return Result.new(evaluation: nil, assessment: nil, error: scored.error) if scored.error

      evaluation = Assignments::RubricEvaluation.find_or_initialize_by(institution: assignment.institution,
        assignment: assignment, student: student)
      evaluation.update!(levels_by_criterion: levels_by_criterion.transform_keys(&:to_s).transform_values(&:to_s),
        evaluated_by: evaluated_by)

      graded = Assignments::GradeRecorder.call(assignment: assignment, student: student, score: scored.score)
      Result.new(evaluation: evaluation, assessment: graded.assessment, error: graded.error)
    end

    private

    attr_reader :assignment, :student, :levels_by_criterion, :evaluated_by
  end
end
