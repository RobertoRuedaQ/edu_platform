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

    # Scope-covering descriptor (same trick as GroupManagement::Section#group_id
    # and StaffManagement::Department#department_id) — a grade level IS its own
    # :grade_level scope id. calendar (v1.27.0) is the FIRST real consumer of
    # role_assignments.scope_grade_level_id outside PermissionCheck itself:
    # Calendar::EventsController passes a GradeLevel to authorize!("calendar.
    # manage", grade_level), and Authorization::Assignment::SCOPE_READERS
    # [:grade_level] reads exactly this method to decide covers?.
    def grade_level_id
      id
    end
  end
end
