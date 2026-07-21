module AnalyticsBi
  # The level chosen per dimension for one CharacterEvaluation. dimension_key
  # references the FROZEN framework_snapshot (a dimension's id captured at
  # publish), NOT a live FK to character_dimensions — same mold as rubric scores,
  # so editing or deleting a framework never rewrites a published evaluation.
  class CharacterDimensionScore < ApplicationRecord
    self.table_name = "character_dimension_scores"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :evaluation, class_name: "AnalyticsBi::CharacterEvaluation"

    validates :dimension_key, presence: true
    validates :level_label, presence: true
  end
end
