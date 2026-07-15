module Portals
  # Read-only, published-only boletines for the signed-in student themself.
  # Resolved by relation (Core::Access::StudentSelfScope), NOT role_assignments
  # — same as StudentPortalController. No authorize! (§7).
  class StudentReportCardsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @report_cards = if @student
        ReportCards::ReportCard
          .where(institution_id: Current.institution_id, student_id: @student.id, status: "published")
          .order(published_at: :desc)
      else
        ReportCards::ReportCard.none
      end
    end
  end
end
