module ControlPlane
  # RBAC intra-plano (v1.31.0) — before this slice, ANY authenticated active
  # platform_admin administered the entire control plane (catalog,
  # subscriptions, entitlements, billing, other admins) with zero scoping.
  # Deliberately NOT the tenant-side model (roles/permissions/role_assignments
  # tables, scope columns): platform admins are a small, curated ops team, not
  # a self-service RBAC system — a static role -> permission-set mapping in
  # code is the "aburrido" fit, same spirit as IdentityAccess::RoleRoster's
  # PERMISSIONS_BY_ROLE_KEY, minus any per-tenant scoping (there is none here).
  #
  # Reads (index/show) stay open to EVERY active platform_admin regardless of
  # role — only MUTATING actions are gated. Same split as the tenant side:
  # authorize! guards writes; a plain view/read is membership-level, not RBAC.
  module Authorization
    extend ActiveSupport::Concern

    NotAuthorized = Class.new(StandardError)

    PERMISSIONS_BY_ROLE = {
      "super_admin" => %w[catalog.manage institutions.manage billing.manage platform_admins.manage],
      "billing_ops" => %w[institutions.manage billing.manage],
      "viewer"      => []
    }.freeze

    included do
      helper_method :can_platform?
      rescue_from NotAuthorized, with: :deny_platform_access
    end

    private

    # Puerta dura — llamada a mano al inicio de cada acción mutante, mismo
    # molde que el `authorize!` del lado del inquilino.
    def authorize_platform!(permission)
      return if can_platform?(permission)

      raise NotAuthorized, "El rol #{current_platform_admin.role} no tiene el permiso #{permission}."
    end

    # Cosmético — para ocultar botones en la vista, nunca el gate real.
    def can_platform?(permission)
      PERMISSIONS_BY_ROLE.fetch(current_platform_admin.role, []).include?(permission)
    end

    def deny_platform_access(_exception)
      respond_to do |format|
        format.html { render "control_plane/errors/forbidden", status: :forbidden }
        format.any  { head :forbidden }
      end
    end
  end
end
