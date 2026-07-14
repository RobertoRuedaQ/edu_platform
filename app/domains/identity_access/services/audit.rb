module IdentityAccess
  # Single write path for audit_events. Intentionally a thin create! — the
  # DB REVOKEs UPDATE/DELETE from the runtime role, so append-only is enforced
  # below this module, not by it.
  module Audit
    def self.log(institution:, action:, actor_institution_user: nil, target: nil, metadata: {}, ip: nil)
      AuditEvent.create!(
        institution: institution, actor_institution_user: actor_institution_user,
        action: action, target_type: target&.class&.name, target_id: target&.id,
        metadata: metadata, ip: ip
      )
    end
  end
end
