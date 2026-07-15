module Assignments
  # Grading a student on an assignment is an UPDATE of the Assessment row
  # Assignments::Publisher already fanned out at publish time — never a
  # second CREATE (that would duplicate the gradebook entry). The score is
  # written directly to schedules::Assessment, the ONE gradebook — exactly
  # where ReportCards::Computation and every other grade reader already
  # looks, so nothing downstream needs to know assignments exist.
  class GradeRecorder
    Result = Data.define(:assessment, :error)

    def self.call(assignment:, student:, score:)
      new(assignment: assignment, student: student, score: score).call
    end

    def initialize(assignment:, student:, score:)
      @assignment = assignment
      @student = student
      @score = score
    end

    def call
      assessment = Schedules::Assessment.joins(:enrollment)
        .where(institution_id: assignment.institution_id, assignment_id: assignment.id,
          enrollments: { student_id: student.id }).first
      return Result.new(assessment: nil, error: :not_in_roster) if assessment.nil?

      assessment.update!(score: score, assessed_on: Date.current)
      Result.new(assessment: assessment, error: nil)
    end

    private

    attr_reader :assignment, :student, :score
  end
end
