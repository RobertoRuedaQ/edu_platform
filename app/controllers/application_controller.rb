class ApplicationController < ActionController::Base
  # Order matters: TenantScoped's around_action must WRAP Authentication's
  # before_action, so the tenant GUC is set (SET LOCAL, inside the request
  # transaction) before any auth query — session resume, membership lookup —
  # runs. Include TenantScoped first so it registers earliest in the chain.
  include TenantScoped
  include Authentication

  # Hard authorization gate: authorize! (protection) + can? (cosmetic view helper).
  include Authorization::Controller

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
