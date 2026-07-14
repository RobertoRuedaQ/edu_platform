class ApplicationController < ActionController::Base
  # Order matters: TenantScoped's around_action must WRAP Authentication's
  # before_action, so the tenant GUC is set (SET LOCAL, inside the request
  # transaction) before any auth query — session resume, membership lookup —
  # runs. Include TenantScoped first so it registers earliest in the chain.
  include TenantScoped
  include Authentication

  # Hard authorization gate: authorize! (protection) + can? (cosmetic view helper).
  include Authorization::Controller

  # Gate #1, ahead of gate #2 above: "can the INSTITUTION use this module?"
  # (S2b). Included LAST on purpose — its before_action must run AFTER
  # TenantScoped resolves Current.institution and Authentication resolves
  # Current.session, both of which it (and the page it may render) depend on.
  # It still runs before authorize! regardless of position: that's called
  # manually inside actions, never registered as a before_action.
  include Entitlement::Controller

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
