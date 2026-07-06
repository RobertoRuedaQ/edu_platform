module Schedules
  # A student enrolled in a subject for a term.
  class Enrollment < ApplicationRecord
    self.table_name = "enrollments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student", inverse_of: :enrollments
    belongs_to :subject, class_name: "Schedules::Subject",       inverse_of: :enrollments
    has_many :assessments, class_name: "Schedules::Assessment",
             foreign_key: :enrollment_id, inverse_of: :enrollment, dependent: :destroy
  end
end
