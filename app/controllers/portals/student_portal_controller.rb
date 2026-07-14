module Portals
  # The student's own dashboard — resolved by relation
  # (Core::Access::StudentSelfScope, students.user_id), NOT by role_assignments:
  # a student is a person-entity, not an RBAC role, so there is no authorize!
  # here. See app/views/layouts/portal.html.erb for the minimal shell.
  class StudentPortalController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
    end
  end
end
