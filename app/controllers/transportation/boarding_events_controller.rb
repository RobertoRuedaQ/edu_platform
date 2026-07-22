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
        emit_usage(event)
        flash[:notice] = "Registro de #{event.event_type_label.downcase} guardado."
      else
        flash[:alert] = event.errors.full_messages.to_sentence
      end
      redirect_to transportation_boarding_path
    end

    private

    # M1 (OPEN_PROCESS.md item #5, molde S3b v1.30.0): one "abordajes" unit
    # per real BoardingEvent row — each boarding/alighting scan is its own
    # distinct real-world event (unlike attendance, there is no (route,
    # student, day) uniqueness to collapse into), so the event's own id is
    # the idempotency anchor.
    def emit_usage(event)
      ControlPlane::Usage::Ingest.emit(institution: Current.institution, addon_key: "transportation",
        unit: "abordajes", occurred_at: event.created_at, idempotency_key: "boarding_event:#{event.id}")
    end
  end
end
