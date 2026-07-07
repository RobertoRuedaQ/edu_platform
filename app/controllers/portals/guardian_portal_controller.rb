module Portals
  # The guardian's own dashboard — child selector + per-child shortcuts.
  # Resolved by relation (guardian_students), NOT by role_assignments: see
  # Portals::GuardianDashboard for the open decision on why this is relational
  # rather than an RBAC role. No authorize! here for the same reason.
  #
  # TODO: reemplazar por StudentSupport::Guardian -> guardian_students reales.
  class GuardianPortalController < ApplicationController
    layout "portal"

    def show
      @dashboard = Portals::GuardianDashboard.stub
      @portal_label = "Portal del acudiente"
      @portal_person_name = @dashboard.guardian_name
    end
  end
end
