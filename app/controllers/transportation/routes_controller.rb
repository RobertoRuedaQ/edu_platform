module Transportation
  class RoutesController < ApplicationController
    def index
      authorize!("routes.view")
      @routes = Transportation::RouteScope.new(context: authorization_context).resolve
    end

    def show
      @route = Transportation::Route.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @route.nil?

      authorize!("routes.view", @route)
      @riders = @route.route_riders.includes(:student, :route_stop).order(:shift)
    end
  end
end
