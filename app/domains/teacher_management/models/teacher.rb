module TeacherManagement
  # A teacher/professor. Both genders represented. University teachers belong
  # to a faculty.
  class Teacher < ApplicationRecord
    self.table_name = "teachers"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :faculty, class_name: "GroupManagement::Faculty", optional: true
    has_many :teaching_assignments, class_name: "TeacherManagement::TeachingAssignment",
             foreign_key: :teacher_id, inverse_of: :teacher, dependent: :destroy

    validates :first_name, :last_name, :gender, :teacher_code, presence: true
  end
end
