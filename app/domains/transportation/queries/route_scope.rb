module Transportation
  # Reused by both RoutesController (routes.view) and BoardingController
  # (boarding.manage — finds the driver/route_monitor's OWN route via the
  # :route scope, same seam, different permission).
  class RouteScope
    def initialize(context:, permission: "routes.view")
      @context = context
      @permission = permission
    end

    def resolve
      RouteRoster.all.select { |route| @context.can?(@permission, route) }
    end
  end
end
