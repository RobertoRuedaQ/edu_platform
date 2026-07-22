module StudentSupport
  # A single convivencia/disciplinary incident report (guidelines/
  # CLOSURE_PLAN.md §3.1/Fase B, Clase S carve-out — molde `counseling`).
  # Immutable once written: no update/destroy route exists — a correction is a
  # NEW entry, never an edit to history (same append-only posture as every
  # other sensitive log in this codebase, just without a status lifecycle
  # since there is nothing to open/close here).
  class DisciplinaryLog < ApplicationRecord
    self.table_name = "disciplinary_logs"

    CATEGORIES = %w[attendance conduct academic_integrity other].freeze
    CATEGORY_LABELS = {
      "attendance" => "Ausentismo", "conduct" => "Convivencia",
      "academic_integrity" => "Integridad académica", "other" => "Otro"
    }.freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :reported_by, class_name: "Core::InstitutionUser",
      foreign_key: :reported_by_institution_user_id

    validates :category, inclusion: { in: CATEGORIES }
    validates :description, :occurred_at, presence: true

    # Scope-covering descriptor (#4 barrido): a log has no group column of its
    # own — derived from the student it's about, same trick as
    # counseling_cases/care_auras/character_evaluations.
    delegate :group_id, to: :student, allow_nil: true

    def category_label = CATEGORY_LABELS.fetch(category, category.to_s.humanize)
    def reported_by_name = reported_by.user.name
  end
end
