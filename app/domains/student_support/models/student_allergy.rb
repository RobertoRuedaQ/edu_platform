module StudentSupport
  # ONE allergy/contraindication for a student (guidelines/CLOSURE_PLAN.md
  # Fase D) — the NARROW tier (medical_history.view_summary, counselor).
  # Independent of MedicalHistory (a school can record an allergy before a
  # full medical record exists) — never joined through it, so the narrow-tier
  # read path structurally cannot reach conditions/medications even by
  # accident (same allowlist-by-construction discipline as
  # AnalyticsBi::Lens::AuraScope's 4-field Data, applied here to a table
  # boundary instead of a serializer).
  #
  # severity is stored in ENGLISH (mild/moderate/severe/anaphylaxis) from the
  # start — this table is net-new, so it matches shared/_allergen_flag's own
  # vocabulary directly, no translation layer needed (contrast
  # Cafeteria::DietaryRestriction, v1.47.0, which had to translate from
  # legacy Spanish seed data because that table already existed).
  class StudentAllergy < ApplicationRecord
    self.table_name = "student_allergies"

    SEVERITIES = %w[mild moderate severe anaphylaxis].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"

    validates :allergen_name, presence: true
    validates :severity, inclusion: { in: SEVERITIES }

    def severity_symbol = severity.to_sym
  end
end
