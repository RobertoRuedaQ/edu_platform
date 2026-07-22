module Schedules
  class RoomScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Schedules::Room.where(institution_id: institution.id).order(:name)
        .select { |room| context.can?("rooms.view", room) }
    end

    private

    attr_reader :context, :institution
  end
end
