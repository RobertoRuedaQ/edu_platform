module Transportation
  # Reused by both RoutesController (routes.view) and BoardingController
  # (boarding.manage — finds the driver/route_monitor's OWN route via the
  # :route scope, same seam, different permission). institution_id explicit,
  # never default_scope, per-row can? — same molde as every other domain
  # index in this codebase.
  class RouteScope
    def initialize(context:, institution: Current.institution, permission: "routes.view")
      @context = context
      @institution = institution
      @permission = permission
    end

    def resolve
      Transportation::Route
        .where(institution_id: institution.id)
        .includes(:driver_staff_member)
        .order(:name)
        .select { |route| context.can?(permission, route) }
    end

    private

    attr_reader :context, :institution, :permission
  end
end
