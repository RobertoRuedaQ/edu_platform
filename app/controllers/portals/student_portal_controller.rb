module Portals
  # The student's own dashboard — a person surface, separate from the staff
  # shell. Resolved by relation (students.user_id), NOT by role_assignments:
  # a student is a person-entity, not an RBAC role, so there is no authorize!
  # here. See app/views/layouts/portal.html.erb for the minimal shell.
  #
  # TODO: reemplazar por Core::User -> GroupManagement::Student (students.user_id).
  class StudentPortalController < ApplicationController
    layout "portal"

    def show
      @dashboard = Portals::StudentDashboard.stub
      @portal_label = "Portal del estudiante"
      @portal_person_name = @dashboard.student_name
    end
  end
end
