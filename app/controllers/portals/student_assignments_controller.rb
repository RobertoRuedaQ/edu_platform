module Portals
  # Read-only, published-only, by self-scope — same discipline as
  # StudentReportCardsController. Shows the student's OWN grade for each
  # assignment, read from the SAME schedules::Assessment row report_cards
  # reads (Assignments::StudentView), never a parallel calculation. No
  # submission action (slice 2).
  class StudentAssignmentsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @assignments = @student ? Assignments::StudentView.for(@student) : Assignments::Assignment.none
    end

    def score_for(assignment)
      Assignments::StudentView.score_for(assignment, @student)
    end
    helper_method :score_for
  end
end
