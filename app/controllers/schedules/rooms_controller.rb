module Schedules
  class RoomsController < ApplicationController
    def index
      authorize!("rooms.view")
      @rooms = Schedules::RoomScope.new(context: authorization_context).resolve
    end

    def show
      @room = Schedules::RoomRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("rooms.view", @room)
      @events = Schedules::ScheduleEventRoster.all.select { |event| event.room_name == @room.name }
    end
  end
end
