module Portals
  # Resolved by relation, same as StudentPortalController — no authorize! here.
  class StudentCafeteriaController < ApplicationController
    layout "portal"

    def show
      @account = Portals::StudentCafeteriaAccount.stub
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
    end
  end
end
