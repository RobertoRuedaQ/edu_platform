module AnalyticsBi
  # One dimension of a CharacterFramework (e.g. Lógica, Creatividad, Empatía,
  # Convivencia, Perseverancia — the doc's own §5.4 starter set). weight is a
  # RELATIVE weight, never forced to sum to 100 (same as RubricCriterion).
  class CharacterDimension < ApplicationRecord
    self.table_name = "character_dimensions"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :framework, class_name: "AnalyticsBi::CharacterFramework"
    has_many :character_levels, -> { order(:position) },
      class_name: "AnalyticsBi::CharacterLevel",
      foreign_key: :dimension_id, inverse_of: :dimension, dependent: :destroy

    validates :name, presence: true
    validates :weight, numericality: { greater_than: 0 }
  end
end
