module Transportation
  # Apéndice A is explicit: "solo UI; broadcast es posterior" — this flashes a
  # stub confirmation and redirects; it does not persist per-rider state.
  # TODO: reemplazar por un modelo real de eventos de abordaje + broadcast.
  class BoardingEventsController < ApplicationController
    def create
      @route = Transportation::RouteRoster.find(params[:route_id]) or raise ActiveRecord::RecordNotFound
      authorize!("boarding.manage", @route)

      flash[:notice] = "Registro de #{params[:status_label] || 'abordaje'} guardado (stub)."
      redirect_to transportation_boarding_path
    end
  end
end
