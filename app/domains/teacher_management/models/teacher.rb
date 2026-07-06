module TeacherManagement
  # A teacher/professor. Both genders represented. University teachers belong
  # to a faculty.
  class Teacher < ApplicationRecord
    self.table_name = "teachers"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :faculty, class_name: "GroupManagement::Faculty", optional: true
    # D1: a teacher is the teaching extension of a staff_member (nullable link
    # during the additive transition; see staff_management).
    belongs_to :staff_member, class_name: "StaffManagement::StaffMember",
               optional: true, inverse_of: :teacher
    has_many :teaching_assignments, class_name: "TeacherManagement::TeachingAssignment",
             foreign_key: :teacher_id, inverse_of: :teacher, dependent: :destroy

    validates :first_name, :last_name, :gender, :teacher_code, presence: true
  end
end
