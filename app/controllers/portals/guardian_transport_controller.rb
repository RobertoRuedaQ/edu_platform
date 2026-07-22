module Portals
  # Resolved by relation, same as GuardianPortalController — no authorize! here.
  class GuardianTransportController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @children = Core::Access::GuardianScope.for(Current.user)
      @riders_by_child = @children.index_with { |child| Transportation::RiderView.for(student: child) }
    end
  end
end
