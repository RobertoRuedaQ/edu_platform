module Portals
  # Resolved by relation (Core::Access::GuardianScope), no authorize! — same
  # discipline as GuardianFinanceController. Summarizes ALL children on one
  # page (config/routes.rb: cafeteria/transport are the two portal surfaces
  # that summarize instead of nesting per-child like finance/report_cards).
  class GuardianCafeteriaController < ApplicationController
    layout "portal"

    def show
      @accounts = Portals::GuardianCafeteriaAccount.for_children(Current.user)
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
    end
  end
end
