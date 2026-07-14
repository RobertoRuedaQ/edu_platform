# frozen_string_literal: true

module ControlPlane
  # View helpers for the control plane. Mixed into control-plane views only via
  # `helper ControlPlane::NavHelper` in BaseController — NOT globally available to
  # the tenant app.
  module NavHelper
    # The sidebar destinations, in display order: [label, path]. url helpers are
    # available here because this module is mixed into the view context.
    def cp_nav_items
      [
        [ "Dashboard",       control_plane_root_path ],
        [ "Administradores", control_plane_platform_admins_path ],
        [ "Instituciones",   control_plane_institutions_path ],
        [ "Catálogo addons", control_plane_addons_path ],
        [ "Entitlements",    control_plane_entitlements_path ],
        [ "Planes y precios", control_plane_plans_path ],
        [ "Uso / metering",  control_plane_usage_path ],
        [ "Facturación",     control_plane_invoices_path ],
        [ "Auditoría",       control_plane_audit_entries_path ]
      ]
    end
  end
end
