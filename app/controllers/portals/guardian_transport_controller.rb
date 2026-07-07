module Portals
  # Resolved by relation, same as GuardianPortalController — no authorize! here.
  class GuardianTransportController < ApplicationController
    layout "portal"

    def show
      @infos = Portals::GuardianTransportInfo.for_children
      @portal_label = "Portal del acudiente"
      @portal_person_name = Portals::GuardianDashboard.stub.guardian_name
    end
  end
end
