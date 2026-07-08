module ControlPlane
  # Mirrors IdentityAccess::Audit's shape for the control plane's own,
  # separate audit trail. platform_admin is nil for events where none could
  # be resolved (unknown-email login attempts, bootstrap) — the attempted
  # email, if any, goes in metadata, never in a way that reveals whether the
  # account exists.
  module Audit
    def self.log(action:, platform_admin: nil, target: nil, metadata: {}, ip_address: nil)
      AuditEvent.create!(
        platform_admin: platform_admin, action: action,
        target_type: target&.class&.name, target_id: target&.id,
        metadata: metadata, ip_address: ip_address
      )
    end
  end
end
