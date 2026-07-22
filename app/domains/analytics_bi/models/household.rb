module AnalyticsBi
  # An optional grouping of caregivers who share a home (BI_DOCUMENT.md §5.6,
  # Slice 8) — pure typology, no addresses/PII beyond the `kind` label. Feeds
  # the orbital graph's "same household" grouping; a student's guardians with no
  # household set are simply ungrouped orbits, never an error.
  class Household < ApplicationRecord
    self.table_name = "households"

    KINDS = %w[nuclear single_parent extended blended other].freeze

    belongs_to :institution, class_name: "Core::Institution"
    has_many :guardian_relationships, class_name: "AnalyticsBi::GuardianRelationship",
      foreign_key: :household_id, inverse_of: :household, dependent: :nullify

    validates :kind, inclusion: { in: KINDS }
  end
end
