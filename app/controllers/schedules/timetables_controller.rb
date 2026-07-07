module Schedules
  # The institutional timetable builder. This phase renders the read grid and
  # highlights the stub conflict flag — it never computes conflicts, and there
  # is no drag/drop editor yet (no periods/rooms model exists to edit against).
  class TimetablesController < ApplicationController
    def show
      authorize!("timetable.manage")
      @events = Schedules::TimetableScope.new(context: authorization_context).resolve
    end
  end
end
