module Schedules
  class RoomScope
    def initialize(context:)
      @context = context
    end

    def resolve
      RoomRoster.all.select { |room| @context.can?("rooms.view", room) }
    end
  end
end
