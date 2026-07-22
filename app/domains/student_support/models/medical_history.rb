module StudentSupport
  # ONE medical record per student (guidelines/CLOSURE_PLAN.md Fase D) — the
  # OWNER tier (medical_history.view). conditions/medications are jsonb
  # string arrays — unstructured free-text lists, never queried
  # structurally, so no normalized table was warranted (contrast with
  # StudentAllergy, which IS its own table because the narrow-tier read
  # needs allergies WITHOUT the rest of this record ever loading).
  #
  # No RLS-bypassing, no encryption: same posture as `counseling`'s clinical
  # notes (Counseling::SessionNote) — RLS + RBAC (medical_history.view/
  # .view_summary) is this codebase's real protection mechanism for
  # sensitive tiers, not column-level encryption (grep-confirmed: `encrypts`
  # is used ONLY for national_id, nowhere in `counseling`).
  class MedicalHistory < ApplicationRecord
    self.table_name = "medical_histories"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"

    validates :student_id, uniqueness: { scope: :institution_id }

    def student_name = "#{student.first_name} #{student.last_name}"
  end
end
