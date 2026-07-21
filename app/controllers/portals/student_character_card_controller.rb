module Portals
  # Lens 2 "Ficha de Personaje" for the student's OWN view (BI_DOCUMENT.md §4,
  # §5.4, Slice 6). Self-service by identity: Core::Access::StudentSelfScope
  # (nil-safe find_by semantics), no authorize!, outside Navigation::Registry —
  # same discipline as StudentCalendarController.
  class StudentCharacterCardController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @card = @student && AnalyticsBi::Lens::CharacterCard.call(student: @student)
    end
  end
end
