module ControlPlane
  # GLOBAL — mirrors Core::Session's shape, but belongs to a platform_admin
  # instead of a tenant user. No RLS, no institution.
  class Session < ApplicationRecord
    self.table_name = "control_plane_sessions"

    belongs_to :platform_admin, class_name: "ControlPlane::PlatformAdmin"
  end
end
