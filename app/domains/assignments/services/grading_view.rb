module Assignments
  # THE single read path for the teacher's grading page — pairs the roster,
  # the fanned-out grade, and the student's submission (if any) in ONE place
  # (same pattern as Finance::AccountStatement), instead of the view
  # threading three separate lookups together itself. Grading and
  # submitting stay independent axes here too — a Row's assessment/
  # submission are each independently nilable.
  module GradingView
    Row = Data.define(:student, :assessment, :submission)
    module_function

    def for(assignment)
      roster = Assignments::Roster.for_subject(assignment.subject, institution: assignment.institution)
        .order(:last_name, :first_name)

      assessments = Schedules::Assessment.joins(:enrollment)
        .where(assignment_id: assignment.id)
        .index_by { |assessment| assessment.enrollment.student_id }
      submissions = Assignments::Submission.where(assignment_id: assignment.id).index_by(&:student_id)

      roster.map do |student|
        Row.new(student: student, assessment: assessments[student.id], submission: submissions[student.id])
      end
    end
  end
end
