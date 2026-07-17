# frozen_string_literal: true

module ControlPlane
  # Base controller for the PLATFORM control plane (super-admin).
  #
  # This plane is CROSS-TENANT and lives ABOVE row-level security. It is NOT a
  # tenant domain, so it deliberately does NOT inherit from ApplicationController
  # and does NOT include TenantScoped: `institution_id` here is a global FK, never
  # an RLS scope key.
  #
  # S0 note: this plane's own tables (platform_admins, control_plane_sessions,
  # control_plane_email_otps, control_plane_audit_events) are global, RLS-free,
  # and served by the normal edu_app_runtime role — NOT by an audited BYPASSRLS
  # role. BYPASSRLS stays reserved for analytics_bi's edu_bi_reader; it is never
  # used here (see PROJECT_STATE.md §7 reconciliation). A dedicated cross-tenant
  # write role for future S1+ tenant-facing reads is a documented hardening idea,
  # not something this slice builds.
  class BaseController < ActionController::Base
    include ControlPlane::Authentication
    include ControlPlane::Authorization

    layout "control_plane"

    # Platform templates + layout live under app/control_plane/views, kept out of
    # the tenant app's app/views on purpose.
    prepend_view_path Rails.root.join("app/control_plane/views")

    # Control-plane view helpers, scoped to this plane only.
    helper ControlPlane::NavHelper
    helper_method :current_platform_admin

    private

    def current_platform_admin
      ControlPlane::Current.platform_admin
    end
  end
end
