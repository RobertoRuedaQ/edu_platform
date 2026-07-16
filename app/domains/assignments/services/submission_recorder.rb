module Assignments
  # Upsert — last-write-wins on the unique (assignment_id, student_id) or
  # (assignment_id, submission_group_id), depending on assignment.group_work?
  # (v1.23.0). For a group assignment, ANY member's student resolves to the
  # SAME shared row (via their GroupMembership) — that's what makes "any
  # member edits the group's one entrega" work, with zero group_id param
  # ever accepted from the caller. The caller is responsible for the
  # security gate: resolving `assignment` through
  # Assignments::StudentView.for(student) (the SAME scope that bounds what
  # the portal can READ) BEFORE calling this — this service itself trusts
  # its arguments, same division of responsibility as
  # Communication::MessageSender/ConversationComposer. A student with no
  # group yet raises (RecordNotFound -> 404) — reachable only via a stale/
  # tampered request, since the portal view never renders a submission form
  # without a resolved group in the first place.
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
      submission = if assignment.group_work?
        group = Assignments::GroupMembership.find_by!(assignment_id: assignment.id, student_id: student.id)
          .submission_group
        Submission.find_or_initialize_by(institution: assignment.institution, assignment: assignment,
          submission_group: group)
      else
        Submission.find_or_initialize_by(institution: assignment.institution, assignment: assignment,
          student: student)
      end

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
