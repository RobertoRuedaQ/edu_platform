module IdentityAccess
  # Append-only audit trail. created_at only, no updated_at — the runtime role
  # is REVOKEd UPDATE/DELETE at the DB level so history cannot be rewritten.
  class AuditEvent < ApplicationRecord
    self.table_name = "audit_events"
    self.record_timestamps = false

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :actor_institution_user, class_name: "Core::InstitutionUser", optional: true

    validates :action, presence: true

    # "System" for job/system-driven events (no human actor — see the nullable
    # actor_institution_user FK's comment on the original migration).
    def actor_label
      actor_institution_user&.user&.name || "Sistema"
    end

    # Minimal, non-navigable reference to what the event happened to — never a
    # link into a directory (AV7). target_type/target_id are loose columns,
    # not a real polymorphic association, so this resolves the handful of real
    # target classes Audit.log is ever called with explicitly rather than via
    # ActiveRecord::Base.const_get on arbitrary string input.
    def target_label
      return nil if target_type.blank?

      case target_type
      when "Core::User"
        Core::User.find_by(id: target_id)&.name
      when "IdentityAccess::Invitation"
        IdentityAccess::Invitation.find_by(id: target_id)&.user&.name
      when "Core::RosterImportBatch"
        batch = Core::RosterImportBatch.find_by(id: target_id)
        batch && "Carga de #{batch.kind}"
      end
    end
  end
end
