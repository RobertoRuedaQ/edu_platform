module Schedules
  # "Mi horario": events filtered to the groups the actor's grants cover.
  # Same seam as every other index — explicit per-row can?, never default_scope.
  class ScheduleScope
    def initialize(context:)
      @context = context
    end

    def resolve
      ScheduleEventRoster.all.select { |event| @context.can?("schedule.view", event) }
    end
  end
end
