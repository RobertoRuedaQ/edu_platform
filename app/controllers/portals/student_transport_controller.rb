module Portals
  # Resolved by relation, same as StudentPortalController — no authorize! here.
  class StudentTransportController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      student = Core::Access::StudentSelfScope.for(Current.user)
      @riders = student ? Transportation::RiderView.for(student: student) : Transportation::RouteRider.none
    end
  end
end
