module Portals
  # Resolved by self-scope (Core::Access::StudentSelfScope), no authorize! —
  # same discipline as StudentAttendanceController.
  class StudentCafeteriaController < ApplicationController
    layout "portal"

    def show
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @account = Portals::StudentCafeteriaAccount.for(@student)
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
    end
  end
end
