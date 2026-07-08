module IdentityAccess
  # Append-only audit trail. created_at only, no updated_at — the runtime role
  # is REVOKEd UPDATE/DELETE at the DB level so history cannot be rewritten.
  class AuditEvent < ApplicationRecord
    self.table_name = "audit_events"
    self.record_timestamps = false

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :actor_institution_user, class_name: "Core::InstitutionUser", optional: true

    validates :action, presence: true
  end
end
