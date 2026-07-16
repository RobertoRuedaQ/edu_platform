module Assignments
  # A column of the matrix, SHARED by every criterion in the template
  # (e.g. Incompleto/Básico/Bueno/Excelente) — never per-criterion.
  class RubricLevel < ApplicationRecord
    self.table_name = "rubric_levels"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :rubric_template, class_name: "Assignments::RubricTemplate"
    has_many :rubric_cell_descriptors, class_name: "Assignments::RubricCellDescriptor",
      foreign_key: :rubric_level_id, inverse_of: :rubric_level, dependent: :destroy

    validates :label, presence: true
    validates :points, numericality: { greater_than_or_equal_to: 0 }
  end
end
