module GroupManagement
  # A student. School students have grade_level + section; university students
  # have a program. Everyone lives in the same city for this seed.
  class Student < ApplicationRecord
    self.table_name = "students"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :grade_level, class_name: "GroupManagement::GradeLevel", optional: true, inverse_of: :students
    belongs_to :section,     class_name: "GroupManagement::Section",    optional: true, inverse_of: :students
    belongs_to :program,     class_name: "GroupManagement::Program",    optional: true, inverse_of: :students

    has_many :enrollments,          class_name: "Schedules::Enrollment",
             foreign_key: :student_id, inverse_of: :student, dependent: :destroy
    has_many :student_guardians,    class_name: "StudentSupport::StudentGuardian",
             foreign_key: :student_id, inverse_of: :student, dependent: :destroy
    has_many :guardians, through: :student_guardians, source: :guardian
    has_many :dietary_restrictions, class_name: "Cafeteria::DietaryRestriction",
             foreign_key: :student_id, inverse_of: :student, dependent: :destroy

    validates :first_name, :last_name, :gender, :birthdate, :student_code, presence: true
  end
end
