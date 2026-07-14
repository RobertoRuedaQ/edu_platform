module ControlPlane
  # GLOBAL, append-only — the control plane's OWN audit trail, never the
  # tenant's audit_events (see IdentityAccess::AuditEvent). Append-only is
  # enforced twice: REVOKE UPDATE/DELETE at the DB role level (in the creating
  # migration) is the real backstop; readonly? here just fails fast in-process
  # instead of round-tripping to Postgres for the same rejection.
  class AuditEvent < ApplicationRecord
    self.table_name = "control_plane_audit_events"
    self.record_timestamps = false

    belongs_to :platform_admin, class_name: "ControlPlane::PlatformAdmin", optional: true

    validates :action, presence: true

    def readonly?
      !new_record?
    end
  end
end
