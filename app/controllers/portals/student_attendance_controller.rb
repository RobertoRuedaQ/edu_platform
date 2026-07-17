module Portals
  # The student's own attendance history — by self-scope, no authorize!,
  # outside Navigation::Registry, same discipline as
  # StudentReportCardsController.
  class StudentAttendanceController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @records = @student ? Attendance::StudentView.for(student: @student) : Attendance::AttendanceRecord.none
    end
  end
end
