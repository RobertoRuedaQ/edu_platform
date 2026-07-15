module Assignments
  # Upsert — last-write-wins on the unique (assignment_id, student_id). The
  # caller is responsible for the security gate: resolving `assignment`
  # through Assignments::StudentView.for(student) (the SAME scope that
  # bounds what the portal can READ) BEFORE calling this — this service
  # itself trusts its arguments, same division of responsibility as
  # Communication::MessageSender/ConversationComposer.
  class SubmissionRecorder
    def self.call(assignment:, student:, body:, submitted_by:)
      new(assignment: assignment, student: student, body: body, submitted_by: submitted_by).call
    end

    def initialize(assignment:, student:, body:, submitted_by:)
      @assignment = assignment
      @student = student
      @body = body
      @submitted_by = submitted_by
    end

    def call
      submission = Submission.find_or_initialize_by(institution: assignment.institution, assignment: assignment,
        student: student)
      submission.body = body
      submission.submitted_by_user = submitted_by
      submission.submitted_at = Time.current
      submission.save!
      submission
    end

    private

    attr_reader :assignment, :student, :body, :submitted_by
  end
end
