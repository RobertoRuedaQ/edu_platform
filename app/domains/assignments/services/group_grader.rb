module Assignments
  # A group grade is a BULK-SET of the same score across every member's
  # already-fanned-out schedules::Assessment (v1.21.0) — reuses
  # Assignments::GradeRecorder per member, never a second grade store.
  # Re-applying the group score re-sets EVERY member, including any that
  # were previously overridden individually — there is no baseline tracked
  # (acceptable for this slice, see HISTORIA.md).
  class GroupGrader
    def self.call(assignment:, submission_group:, score:)
      new(assignment: assignment, submission_group: submission_group, score: score).call
    end

    def initialize(assignment:, submission_group:, score:)
      @assignment = assignment
      @submission_group = submission_group
      @score = score
    end

    def call
      submission_group.students.map do |student|
        Assignments::GradeRecorder.call(assignment: assignment, student: student, score: score)
      end
    end

    private

    attr_reader :assignment, :submission_group, :score
  end
end
