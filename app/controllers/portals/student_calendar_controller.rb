module Portals
  # The student's own calendar timeline (v1.27.0) — by self-scope, no
  # authorize!, outside Navigation::Registry, same discipline as
  # StudentAssignmentsController. Merges the real events visible to this
  # student with their published assignments' deadlines (Calendar::Timeline).
  class StudentCalendarController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @entries = @student ? Calendar::Timeline.for(student: @student) : []
    end
  end
end
