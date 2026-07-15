module Assignments
  # THE single read path for "what published assignments does this student
  # have" — consumed by BOTH the student portal and the guardian portal
  # (same pattern as ReportCards::Computation/Communication::Inbox: one
  # computation, many surfaces). Scoped by the student's OWN enrollments in
  # the active term, never a search.
  module StudentView
    module_function

    def for(student, institution: Current.institution)
      active_term = Core::AcademicTerm.active.find_by(institution_id: institution.id)
      return Assignments::Assignment.none if active_term.nil?

      subject_ids = Schedules::Enrollment.where(institution_id: institution.id, student_id: student.id,
        academic_term_id: active_term.id).select(:subject_id)

      Assignments::Assignment.published
        .where(institution_id: institution.id, subject_id: subject_ids)
        .order(due_date: :asc)
    end

    # The student's own grade for this assignment, read from the SAME
    # schedules::Assessment row report_cards reads — never a parallel
    # calculation. nil means "not graded yet" (or the student wasn't on the
    # roster when it was published), never a zero.
    def score_for(assignment, student)
      Schedules::Assessment.joins(:enrollment)
        .find_by(assignment_id: assignment.id, enrollments: { student_id: student.id })
        &.score
    end

    # The student's own submission (v1.22.0), if any — nil means "not
    # submitted yet", never an error. `for` above is THE security gate for
    # writing one (see Assignments::SubmissionRecorder's docstring): a
    # controller must resolve the assignment through `for(student)` before
    # ever calling the recorder.
    def submission_for(assignment, student)
      Assignments::Submission.find_by(assignment_id: assignment.id, student_id: student.id)
    end
  end
end
