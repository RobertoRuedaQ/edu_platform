module Assignments
  # The group sibling of Assignments::RubricGrader — computes ONE score for
  # the whole group from the shared evaluation, persists it (student_id:
  # nil, submission_group_id: set — same identity shape as a group
  # Submission, v1.23.0), then bulk-sets every member's Assessment by
  # reusing Assignments::GroupGrader (v1.23.0) unchanged — never a second
  # bulk-set mechanism. An individual override afterward still goes through
  # the same per-student GradeRecorder path it always has.
  class GroupRubricGrader
    Result = Data.define(:evaluation, :error)

    def self.call(assignment:, submission_group:, levels_by_criterion:, evaluated_by:)
      new(assignment: assignment, submission_group: submission_group, levels_by_criterion: levels_by_criterion,
        evaluated_by: evaluated_by).call
    end

    def initialize(assignment:, submission_group:, levels_by_criterion:, evaluated_by:)
      @assignment = assignment
      @submission_group = submission_group
      @levels_by_criterion = levels_by_criterion
      @evaluated_by = evaluated_by
    end

    def call
      scored = Assignments::RubricScore.call(snapshot: assignment.rubric_snapshot, levels_by_criterion: levels_by_criterion)
      return Result.new(evaluation: nil, error: scored.error) if scored.error

      evaluation = Assignments::RubricEvaluation.find_or_initialize_by(institution: assignment.institution,
        assignment: assignment, submission_group: submission_group)
      evaluation.update!(levels_by_criterion: levels_by_criterion.transform_keys(&:to_s).transform_values(&:to_s),
        evaluated_by: evaluated_by)

      Assignments::GroupGrader.call(assignment: assignment, submission_group: submission_group, score: scored.score)
      Result.new(evaluation: evaluation, error: nil)
    end

    private

    attr_reader :assignment, :submission_group, :levels_by_criterion, :evaluated_by
  end
end
