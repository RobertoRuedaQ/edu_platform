module StudentSupport
  # One accommodation/adaptation for a student (guidelines/CLOSURE_PLAN.md
  # Fase D) — replaces the AccommodationRoster stub, whose
  # AccommodationsController#update was a literal no-op ("STUB: no
  # persistence yet"). `authorized_by_institution_user_id` is identity-only
  # (RESTRICT), same accountability posture as disciplinary_logs/care_auras/
  # character_evaluations authors — never a navigable association beyond
  # identity.
  class Accommodation < ApplicationRecord
    self.table_name = "accommodations"

    KINDS = %w[extra_time adapted_material preferential_seating other].freeze
    STATUSES = %w[active expired].freeze

    KIND_LABELS = {
      "extra_time" => "Tiempo extra", "adapted_material" => "Material adaptado",
      "preferential_seating" => "Ubicación preferencial", "other" => "Otro"
    }.freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :authorized_by, class_name: "Core::InstitutionUser",
      foreign_key: :authorized_by_institution_user_id

    validates :kind, inclusion: { in: KINDS }
    validates :status, inclusion: { in: STATUSES }
    validates :description, presence: true

    # Scope-covering descriptor (#4 barrido): an accommodation has no group
    # column of its own — derived from the student it's about, same trick as
    # disciplinary_logs/care_auras/character_evaluations.
    delegate :group_id, to: :student, allow_nil: true

    def kind_label = KIND_LABELS.fetch(kind, kind.humanize)
  end
end
