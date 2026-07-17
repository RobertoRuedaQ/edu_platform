module Portals
  # A guardian's per-child attendance history — resolved through
  # Core::Access::GuardianScope FIRST (a child outside the caller's own active
  # links 404s), then Attendance::StudentView.for(student:), same two-step
  # relation gate as GuardianCalendarController. No authorize!, outside
  # Navigation::Registry.
  class GuardianAttendanceController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @records = Attendance::StudentView.for(student: @student)
    end
  end
end
