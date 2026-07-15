module Portals
  # Read-only, published-only boletines for ONE of the guardian's own
  # children. Security-critical: #index MUST resolve params[:student_id]
  # through Core::Access::GuardianScope, never GroupManagement::Student.find
  # directly — same discipline as GuardianStudentsController#show. No
  # authorize! (GS6/§7) — the scope IS the gate. Never shows a draft/preview:
  # only status: "published" rows exist to query in the first place.
  class GuardianReportCardsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @report_cards = ReportCards::ReportCard
        .where(institution_id: Current.institution_id, student_id: @student.id, status: "published")
        .order(published_at: :desc)
    end
  end
end
