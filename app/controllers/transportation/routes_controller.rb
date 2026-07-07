module Transportation
  class RoutesController < ApplicationController
    def index
      authorize!("routes.view")
      @routes = Transportation::RouteScope.new(context: authorization_context).resolve
    end

    def show
      @route = Transportation::RouteRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("routes.view", @route)
      @riders = Transportation::RiderRoster.for_route(@route.id)
    end
  end
end
