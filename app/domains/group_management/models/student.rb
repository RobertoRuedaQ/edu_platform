module GroupManagement
  # A student. School students have grade_level + section; university students
  # have a program. Everyone lives in the same city for this seed.
  class Student < ApplicationRecord
    self.table_name = "students"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :grade_level, class_name: "GroupManagement::GradeLevel", optional: true, inverse_of: :students
    belongs_to :section,     class_name: "GroupManagement::Section",    optional: true, inverse_of: :students
    belongs_to :program,     class_name: "GroupManagement::Program",    optional: true, inverse_of: :students
    # Optional login identity for this student.
    belongs_to :user,        class_name: "Core::User", optional: true

    # Deterministic so the (institution_id, national_id) partial unique index
    # can enforce uniqueness against the stored ciphertext.
    encrypts :national_id, deterministic: true

    has_many :enrollments,          class_name: "Schedules::Enrollment",
             foreign_key: :student_id, inverse_of: :student, dependent: :destroy
    # Legacy guardian association (StudentSupport), left untouched.
    has_many :student_guardians,    class_name: "StudentSupport::StudentGuardian",
             foreign_key: :student_id, inverse_of: :student, dependent: :destroy
    has_many :guardians, through: :student_guardians, source: :guardian
    # NEW parallel guardian links, keyed on global users.
    has_many :guardian_students,    class_name: "Core::GuardianStudent",
             dependent: :destroy
    has_many :guardian_users, through: :guardian_students, source: :guardian
    has_many :dietary_restrictions, class_name: "Cafeteria::DietaryRestriction",
             foreign_key: :student_id, inverse_of: :student, dependent: :destroy

    validates :first_name, :last_name, :gender, :birthdate, :student_code, presence: true

    # Scope-covering descriptor (#4 barrido) — section_id already IS the real
    # :group scope column; grade_level_id is likewise already real, so no
    # descriptor is needed for a grade_level-scoped grant.
    def group_id
      section_id
    end
  end
end
