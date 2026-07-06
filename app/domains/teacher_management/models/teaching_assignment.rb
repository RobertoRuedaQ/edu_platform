module TeacherManagement
  # Which teacher teaches which subject.
  class TeachingAssignment < ApplicationRecord
    self.table_name = "teaching_assignments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :teacher, class_name: "TeacherManagement::Teacher", inverse_of: :teaching_assignments
    belongs_to :subject, class_name: "Schedules::Subject"
  end
end
