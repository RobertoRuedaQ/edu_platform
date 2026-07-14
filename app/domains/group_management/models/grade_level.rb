module GroupManagement
  # School grade level (e.g. Grado 6, Grado 11).
  class GradeLevel < ApplicationRecord
    self.table_name = "grade_levels"

    belongs_to :institution, class_name: "Core::Institution"
    has_many :sections, class_name: "GroupManagement::Section",
             foreign_key: :grade_level_id, inverse_of: :grade_level, dependent: :destroy
    has_many :students, class_name: "GroupManagement::Student",
             foreign_key: :grade_level_id, inverse_of: :grade_level

    validates :name, :level_number, presence: true
  end
end
