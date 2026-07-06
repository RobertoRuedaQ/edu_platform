module GroupManagement
  # School class/group within a grade level (A, B, C ...).
  class Section < ApplicationRecord
    self.table_name = "sections"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :grade_level, class_name: "GroupManagement::GradeLevel",
               optional: true, inverse_of: :sections
    has_many :students, class_name: "GroupManagement::Student",
             foreign_key: :section_id, inverse_of: :section

    validates :name, :academic_year, presence: true
  end
end
