module Transportation
  # "Su ruta del día" — resolved the same way every scoped index is: filter
  # the full roster by can?, not a route id in the URL. A driver's grant is
  # scope_type: :route, so this naturally returns just their own route(s).
  class BoardingController < ApplicationController
    def show
      authorize!("boarding.manage")
      @routes = Transportation::RouteScope.new(context: authorization_context, permission: "boarding.manage").resolve
    end
  end
end
