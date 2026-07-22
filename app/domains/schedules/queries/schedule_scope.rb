module Schedules
  # "Mi horario": events filtered to the groups the actor's grants cover.
  # Same seam as every other index — explicit per-row can?, never default_scope.
  class ScheduleScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Schedules::MeetingPatternPresenter.rows_for(institution).select { |row| context.can?("schedule.view", row) }
    end

    private

    attr_reader :context, :institution
  end
end
