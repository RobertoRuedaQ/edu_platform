module AnalyticsBi
  # The reusable, per-institution character-evaluation library (BI_DOCUMENT.md
  # §5.4, Slice 5) — the exact structural mold as assignments' RubricTemplate,
  # but for behavior. Author-owned; editable freely, because a published
  # CharacterEvaluation freezes its OWN immutable framework_snapshot at publish
  # time (same discipline as RubricTemplate/Assignment#rubric_snapshot) — editing
  # or archiving this framework afterward never touches an already-published
  # evaluation.
  class CharacterFramework < ApplicationRecord
    self.table_name = "character_frameworks"

    # Closed set, backed by a DB CHECK (character_frameworks_status_check); the
    # app validation is only here for friendly form errors.
    STATUSES = %w[draft published archived].freeze

    belongs_to :institution, class_name: "Core::Institution"
    has_many :character_dimensions, -> { order(:position) },
      class_name: "AnalyticsBi::CharacterDimension",
      foreign_key: :framework_id, inverse_of: :framework, dependent: :destroy

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :published, -> { where(status: "published") }

    def published?
      status == "published"
    end

    # Built from the LIVE dimensions/levels at the ONE moment this is ever read
    # for evaluation purposes: AnalyticsBi::Character::Publisher freezing a
    # CharacterEvaluation#framework_snapshot. Nothing else calls this. Each
    # dimension carries a stable "key" (its id) so a CharacterDimensionScore can
    # reference the frozen structure by that key, never a live FK (rubric mold).
    def snapshot
      {
        "framework_id" => id,
        "framework_name" => name,
        "dimensions" => character_dimensions.map do |dimension|
          {
            "key" => dimension.id,
            "name" => dimension.name,
            "weight" => dimension.weight.to_s,
            "position" => dimension.position,
            "levels" => dimension.character_levels.map do |level|
              { "label" => level.label, "descriptor" => level.descriptor, "position" => level.position }
            end
          }
        end
      }
    end
  end
end
