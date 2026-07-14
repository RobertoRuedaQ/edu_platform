module Schedules
  # The institutional timetable: same events as ScheduleScope, gated by the
  # broader timetable.manage permission instead of the actor's own group.
  class TimetableScope
    def initialize(context:)
      @context = context
    end

    def resolve
      ScheduleEventRoster.all.select { |event| @context.can?("timetable.manage", event) }
    end
  end
end
