# frozen_string_literal: true

module ControlPlane
  # Base controller for the PLATFORM control plane (super-admin).
  #
  # This plane is CROSS-TENANT and lives ABOVE row-level security. It is NOT a
  # tenant domain, so it deliberately does NOT inherit from ApplicationController
  # and does NOT include TenantScoped: `institution_id` here is a global FK, never
  # an RLS scope key. In production it will be served by an audited Postgres role
  # with BYPASSRLS (never edu_app_runtime) — not wired in this views-only phase.
  #
  # TODO(auth): super-admins are `platform_admins` (separate table, mandatory
  #   MFA), NOT `users`. Replace `require_platform_admin!` with the real guard.
  # TODO(db): connect the audited BYPASSRLS role here; no DB access this phase.
  class BaseController < ActionController::Base
    layout "control_plane"

    # Platform templates + layout live under app/control_plane/views, kept out of
    # the tenant app's app/views on purpose.
    prepend_view_path Rails.root.join("app/control_plane/views")

    # Control-plane view helpers, scoped to this plane only.
    helper ControlPlane::NavHelper

    before_action :require_platform_admin!

    private

    # STUB GUARD — intentionally a no-op so the screens are browsable in this
    # phase. The real version authenticates a ControlPlane::PlatformAdmin session
    # (separate from tenant users) and enforces MFA.
    #
    # TODO: reemplazar por guard real (ControlPlane::PlatformAdmin + MFA) y el
    #       rol Postgres auditado con BYPASSRLS.
    def require_platform_admin!
      true
    end
  end
end
