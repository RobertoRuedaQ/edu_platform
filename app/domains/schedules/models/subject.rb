module Schedules
  # A subject/course, attached to a grade_level (school) or program (university).
  class Subject < ApplicationRecord
    self.table_name = "subjects"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :grade_level, class_name: "GroupManagement::GradeLevel", optional: true
    belongs_to :program,     class_name: "GroupManagement::Program",    optional: true
    has_many :enrollments, class_name: "Schedules::Enrollment",
             foreign_key: :subject_id, inverse_of: :subject, dependent: :destroy

    validates :name, :code, :term, presence: true
  end
end
