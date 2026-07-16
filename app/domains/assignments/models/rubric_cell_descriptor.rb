module Assignments
  # The "what distinguishes Bueno from Excelente" text for ONE (criterion,
  # level) cell — optional. Visible to the student/acudiente through the
  # portal's ordinary relation gate (StudentView/GuardianScope) once the
  # assignment publishes, so the grade is defensible, not just a number.
  class RubricCellDescriptor < ApplicationRecord
    self.table_name = "rubric_cell_descriptors"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :rubric_criterion, class_name: "Assignments::RubricCriterion"
    belongs_to :rubric_level, class_name: "Assignments::RubricLevel"
  end
end
