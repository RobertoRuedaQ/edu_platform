module ControlPlane
  # Per-request context for the control plane — completely separate from the
  # tenant's top-level Current. No institution / institution_user / GUC here:
  # the control plane is cross-tenant by nature and never resolves a tenant.
  # ActiveSupport resets this automatically at the end of every executor
  # cycle, same as the tenant Current, so it cannot bleed between requests.
  class Current < ActiveSupport::CurrentAttributes
    attribute :platform_admin
    attribute :session

    # Derived from the session; nil when unauthenticated.
    def session=(record)
      super
      self.platform_admin = record&.platform_admin
    end
  end
end
