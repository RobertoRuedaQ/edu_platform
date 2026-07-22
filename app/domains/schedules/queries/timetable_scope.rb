module Schedules
  # The institutional timetable: same events as ScheduleScope, gated by the
  # broader timetable.manage permission instead of the actor's own group.
  class TimetableScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Schedules::MeetingPatternPresenter.rows_for(institution).select { |row| context.can?("timetable.manage", row) }
    end

    private

    attr_reader :context, :institution
  end
end
