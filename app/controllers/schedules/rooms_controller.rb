module Schedules
  class RoomsController < ApplicationController
    def index
      authorize!("rooms.view")
      @rooms = Schedules::RoomScope.new(context: authorization_context).resolve
    end

    def show
      @room = Schedules::Room.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @room.nil?

      authorize!("rooms.view", @room)
      @events = Schedules::MeetingPatternPresenter.rows_for(Current.institution).select { |row| row.room_id == @room.id }
    end
  end
end
