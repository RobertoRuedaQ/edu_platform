module Portals
  # Read-only summary of ONE of the guardian's own children. Security-critical:
  # #show MUST resolve `params[:id]` through Core::Access::GuardianScope, never
  # GroupManagement::Student.find directly — a student outside the caller's
  # own active-links scope (revoked link, another guardian's child, another
  # tenant) must 404, never render. No authorize! (GS6, same as
  # GuardianPortalController) — the scope IS the gate.
  class GuardianStudentsController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:id])
      @link = Core::GuardianStudent.active.find_by(guardian_user_id: Current.user.id, student_id: @student.id)
    end
  end
end
