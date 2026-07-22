module AnalyticsBi
  # Metadata layer on top of an EXISTING Core::GuardianStudent link
  # (BI_DOCUMENT.md §5.6, Slice 8, T2 formativo) — extends it 1:1, never
  # duplicates student_id/guardian_user_id/relationship, which stay owned by
  # `core`. This is what the orbital graph (Lens 4) actually reads: which
  # guardian is the PRIMARY caregiver (orbit distance), and — sensitive,
  # §6.2 — the custody dimension.
  #
  # SEGREGATION (§6.2): custody_kind is a plain column (T2, not T3 clinical —
  # does not need counseling's encrypted-column posture), but the graph's read
  # path (AnalyticsBi::Lens::FamilyGraph) NEVER includes it in the orbital
  # payload — only an explicit, separate accessor a caller must opt into,
  # same allowlist-by-construction discipline as AnalyticsBi::Lens::AuraScope
  # (v1.37.0). Never log/serialize this column by default.
  class GuardianRelationship < ApplicationRecord
    self.table_name = "guardian_relationships"

    RELATIONSHIP_KINDS = %w[mother father grandparent legal_guardian sibling other].freeze
    CUSTODY_KINDS = %w[shared sole supervised unspecified].freeze

    RELATIONSHIP_LABELS = {
      "mother" => "Madre", "father" => "Padre", "grandparent" => "Abuelo/a",
      "legal_guardian" => "Tutor legal", "sibling" => "Hermano/a", "other" => "Otro"
    }.freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :guardian_student, class_name: "Core::GuardianStudent"
    belongs_to :household, class_name: "AnalyticsBi::Household", optional: true

    validates :relationship_kind, inclusion: { in: RELATIONSHIP_KINDS }
    validates :custody_kind, inclusion: { in: CUSTODY_KINDS }, allow_nil: true
    validates :guardian_student_id, uniqueness: { scope: :institution_id }

    scope :primary_caregivers, -> { where(is_primary_caregiver: true) }

    delegate :student, :guardian, to: :guardian_student

    def self.relationship_label(kind) = RELATIONSHIP_LABELS.fetch(kind.to_s, kind.to_s.humanize)
  end
end
