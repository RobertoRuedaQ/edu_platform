module StudentSupport
  # Join between a student and a guardian.
  class StudentGuardian < ApplicationRecord
    self.table_name = "student_guardians"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student,  class_name: "GroupManagement::Student", inverse_of: :student_guardians
    belongs_to :guardian, class_name: "StudentSupport::Guardian", inverse_of: :student_guardians
  end
end
