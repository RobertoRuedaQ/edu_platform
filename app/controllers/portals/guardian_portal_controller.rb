module Portals
  # The guardian's own dashboard — lists their real, active acudidos via
  # Core::Access::GuardianScope. Resolved by RELATION, NOT by role_assignments
  # (GS6): a guardian holds zero IdentityAccess::RoleAssignment by design (P1/
  # RosterImport-guardians, v1.8.0), so there is no authorize! here — anyone
  # signed in simply sees their own scope, empty or not (GS9). Read-only
  # (GS8): no forms, no mutations.
  class GuardianPortalController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @children = Core::Access::GuardianScope.for(Current.user)
    end
  end
end
