module Portals
  # Read-only, published-only, per-child (like report_cards/finance — a
  # subject's assignments are inherently per-child, unlike org-wide
  # announcements). #show MUST resolve params[:student_id] through
  # Core::Access::GuardianScope, never GroupManagement::Student.find
  # directly — a child outside the caller's own scope 404s.
  class GuardianAssignmentsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @assignments = Assignments::StudentView.for(@student)
    end

    def score_for(assignment)
      Assignments::StudentView.score_for(assignment, @student)
    end
    helper_method :score_for
  end
end
