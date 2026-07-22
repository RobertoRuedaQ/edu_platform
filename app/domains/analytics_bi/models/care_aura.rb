module AnalyticsBi
  # Lens 5 — "Auras de Cuidado" (BI_DOCUMENT.md §5.7, Slice 3). The clinical-
  # isolation-preserving PROJECTION: counseling owns the diagnosis/detail (T3)
  # and NEVER exposes it; this table is a projection (closed enum + free-text
  # guidance, zero clinical PII) the counselor publishes, and the teacher reads
  # only that projection as an abstract "aura" badge.
  #
  # CLINICAL ISOLATION INVARIANT: there is deliberately NO association here to
  # any counseling model (Case/SessionNote/Referral). authored_by_counselor is
  # a Core::InstitutionUser (identity only) — a plain FK, never a loaded
  # association exposing counselor PII beyond identity. No eager-load or view
  # path can reach counseling data through this model, even by accident.
  #
  # Written ONLY by AnalyticsBi::Aura::Projector, invoked FROM counseling
  # (cross-domain via FK + service call). Read by AnalyticsBi::Aura::
  # CounselorScope (counselor side) and AnalyticsBi::Lens::AuraScope (teacher
  # side, returns a 4-field projection Data, never the AR model).
  class CareAura < ApplicationRecord
    self.table_name = "care_auras"

    # Closed set — an INSTRUCTION OF TREATMENT, never a diagnosis. Backed by a
    # DB CHECK constraint (care_auras_aura_kind_check); the app validation is
    # only here for friendly form errors.
    AURA_KINDS = %w[
      private_or_oral_evaluation
      positive_reinforcement_public
      extra_time
      quiet_space
    ].freeze

    # Single source of truth for the teacher-facing label of each closed kind —
    # shared by the counseling authoring surface and the Lens 1 seat-grid badge.
    # Deliberately non-clinical, action-oriented wording (an instruction of
    # treatment, never a diagnosis).
    KIND_LABELS = {
      "private_or_oral_evaluation"    => "Evaluación privada u oral",
      "positive_reinforcement_public" => "Refuerzo positivo en público",
      "extra_time"                    => "Tiempo adicional",
      "quiet_space"                   => "Espacio tranquilo"
    }.freeze

    def self.kind_label(kind)
      KIND_LABELS.fetch(kind.to_s, kind.to_s.humanize)
    end

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :authored_by_counselor, class_name: "Core::InstitutionUser"

    validates :aura_kind, presence: true, inclusion: { in: AURA_KINDS }
    validates :guidance_text, presence: true
    validates :effective_from, presence: true

    # NULL effective_until == currently in effect (same convention as
    # SeatAssignment). active == the open projection.
    scope :active, -> { where(effective_until: nil) }
    scope :effective_on, ->(date) {
      where("effective_from <= :d AND (effective_until IS NULL OR effective_until >= :d)", d: date)
    }

    # Scope-covering descriptor: an aura has no group column of its own — it's
    # derived from the student it's about (same trick as Counseling::Case#group_id).
    # A group-scoped hps.aura.view grant covers auras for students in that section.
    delegate :group_id, to: :student, allow_nil: true

    def active?
      effective_until.nil?
    end
  end
end
