module Assignments
  # THE single read path for the teacher's grading page — pairs the roster,
  # the fanned-out grade, and the submission (student's own, or their
  # group's shared one, v1.23.0) in ONE place (same pattern as
  # Finance::AccountStatement), instead of the view threading several
  # lookups together itself. Grading and submitting stay independent axes
  # here too — a Row's assessment/submission are each independently nilable
  # (a student with no group yet simply has submission: nil, same empty
  # state as "not submitted", never an error).
  module GradingView
    Row = Data.define(:student, :assessment, :submission, :submission_group)
    module_function

    def for(assignment)
      roster = Assignments::Roster.for_subject(assignment.subject, institution: assignment.institution)
        .order(:last_name, :first_name)

      assessments = Schedules::Assessment.joins(:enrollment)
        .where(assignment_id: assignment.id)
        .index_by { |assessment| assessment.enrollment.student_id }

      if assignment.group_work?
        memberships = Assignments::GroupMembership.where(assignment_id: assignment.id)
          .includes(submission_group: :submission).index_by(&:student_id)

        roster.map do |student|
          group = memberships[student.id]&.submission_group
          Row.new(student: student, assessment: assessments[student.id], submission: group&.submission,
            submission_group: group)
        end
      else
        submissions = Assignments::Submission.where(assignment_id: assignment.id).index_by(&:student_id)

        roster.map do |student|
          Row.new(student: student, assessment: assessments[student.id], submission: submissions[student.id],
            submission_group: nil)
        end
      end
    end
  end
end
