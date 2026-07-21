module AnalyticsBi
  # The first consent primitive in the codebase (BI_DOCUMENT.md §5.4 point 5).
  # The doc's molde "assignments.requires_consent" does NOT exist (grep-confirmed
  # — a stale/aspirational reference, same class Slices 2/3 corrected); this is
  # the minimal, program-scoped replacement.
  #
  # Guardian consent for a minor's PARTICIPATION in the peer path (giving OR
  # receiving appreciations). Program-scoped and owned by analytics_bi — NOT a
  # general Habeas-Data framework (deliberately minimal; do not over-build). The
  # guardian is a global Core::User (same identity column as
  # guardian_students.guardian_user_id).
  #
  # Append-only: granting opens a row (granted_at); revoking closes it
  # (revoked_at). Active consent == a row with revoked_at IS NULL; a DB partial
  # unique index guarantees at most one active row per student. Re-granting after
  # a revoke opens a NEW row, preserving history.
  class CharacterProgramConsent < ApplicationRecord
    self.table_name = "character_program_consents"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :granted_by_guardian, class_name: "Core::User",
      foreign_key: :granted_by_guardian_user_id

    validates :granted_at, presence: true

    scope :active, -> { where(revoked_at: nil) }

    def active?
      revoked_at.nil?
    end

    # Is this student cleared to participate in the peer path right now?
    def self.active_for?(student_id, institution:)
      active.exists?(institution_id: institution.id, student_id: student_id)
    end

    # Grant consent (idempotent: a no-op if an active consent already exists).
    def self.grant!(student:, guardian_user:, institution:)
      existing = active.find_by(institution_id: institution.id, student_id: student.id)
      return existing if existing

      create!(institution: institution, student: student,
        granted_by_guardian: guardian_user, granted_at: Time.current)
    end

    # Revoke the active consent (idempotent: a no-op if none is active).
    def self.revoke!(student:, institution:)
      active.where(institution_id: institution.id, student_id: student.id)
        .update_all(revoked_at: Time.current)
    end
  end
end
