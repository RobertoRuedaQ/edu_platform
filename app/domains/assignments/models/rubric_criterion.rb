module Assignments
  # One row of a RubricTemplate's matrix — a relative weight, not a
  # percentage (the calculation is a ratio, criteria never need to sum to
  # 100; see Assignments::RubricScore).
  class RubricCriterion < ApplicationRecord
    self.table_name = "rubric_criteria"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :rubric_template, class_name: "Assignments::RubricTemplate"
    has_many :rubric_cell_descriptors, class_name: "Assignments::RubricCellDescriptor",
      foreign_key: :rubric_criterion_id, inverse_of: :rubric_criterion, dependent: :destroy

    validates :name, presence: true
    validates :weight, numericality: { greater_than: 0 }
  end
end
