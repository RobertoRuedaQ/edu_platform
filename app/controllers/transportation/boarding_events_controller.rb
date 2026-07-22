module Transportation
  class BoardingEventsController < ApplicationController
    def create
      @route = Transportation::Route.find_by(institution_id: Current.institution_id, id: params[:route_id])
      raise ActiveRecord::RecordNotFound if @route.nil?

      authorize!("boarding.manage", @route)

      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
      raise ActiveRecord::RecordNotFound if student.nil?

      event = Transportation::BoardingEvent.new(
        institution_id: Current.institution_id, route: @route, student: student,
        recorded_by: Current.institution_user, event_type: params[:event_type]
      )
      if event.save
        flash[:notice] = "Registro de #{event.event_type_label.downcase} guardado."
      else
        flash[:alert] = event.errors.full_messages.to_sentence
      end
      redirect_to transportation_boarding_path
    end
  end
end
