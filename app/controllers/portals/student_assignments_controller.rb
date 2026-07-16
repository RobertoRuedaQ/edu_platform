module Portals
  # Read-only listing + detail, published-only, by self-scope — same
  # discipline as StudentReportCardsController. Shows the student's OWN
  # grade for each assignment, read from the SAME schedules::Assessment row
  # report_cards reads (Assignments::StudentView), never a parallel
  # calculation. The write action (submitting) lives on
  # StudentSubmissionsController — this controller stays read-only.
  class StudentAssignmentsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @assignments = @student ? Assignments::StudentView.for(@student) : Assignments::Assignment.none
    end

    # #show is the SAME query as #index, narrowed to :id — an assignment
    # outside the student's own published/enrolled scope 404s here exactly
    # like it would silently not appear in #index (v1.22.0: this scope is
    # also the write gate for StudentSubmissionsController).
    def show
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      raise ActiveRecord::RecordNotFound if @student.nil?

      @assignment = Assignments::StudentView.for(@student).find(params[:id])
      @submission = Assignments::StudentView.submission_for(@assignment, @student)
      # nil for an individual assignment, or for a group one where this
      # student hasn't been placed yet (§0: empty state, never an error).
      @group = Assignments::StudentView.group_for(@assignment, @student)
    end

    def score_for(assignment)
      Assignments::StudentView.score_for(assignment, @student)
    end
    helper_method :score_for

    def assignment_path_for(assignment)
      portal_student_assignment_path(assignment)
    end
    helper_method :assignment_path_for
  end
end
