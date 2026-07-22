module Portals
  # Lens 2 "Ficha de Personaje" for a guardian's per-child view (BI_DOCUMENT.md
  # §4, §5.4, Slice 6). SELF-SERVICE, not supervision: resolved through
  # Core::Access::GuardianScope FIRST (a child outside the caller's own active
  # links 404s — "caso de María"), then the read-model. No authorize!, outside
  # Navigation::Registry — exactly like GuardianAttendanceController. The card is
  # strengths-only and dignified (§1.1.4): never a numeric score.
  class GuardianCharacterCardController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @card = AnalyticsBi::Lens::CharacterCard.call(student: @student)
      @consent = AnalyticsBi::CharacterProgramConsent.active
        .find_by(institution_id: Current.institution_id, student_id: @student.id)
    end
  end
end
