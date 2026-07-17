module Portals
  # A guardian's per-child calendar timeline (v1.27.0) — resolved through
  # Core::Access::GuardianScope FIRST (a child outside the caller's own active
  # links 404s), then Calendar::Timeline.for(student:), same two-step relation
  # gate as GuardianAssignmentsController. No authorize!, outside
  # Navigation::Registry.
  class GuardianCalendarController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @entries = Calendar::Timeline.for(student: @student)
    end
  end
end
