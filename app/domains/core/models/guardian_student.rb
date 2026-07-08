module Core
  # NEW guardian<->student link keyed on a GLOBAL user (guardian_user_id),
  # deliberately separate from the legacy StudentSupport::Guardian /
  # student_guardians tables.
  class GuardianStudent < ApplicationRecord
    self.table_name = "guardian_students"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :guardian, class_name: "Core::User", foreign_key: :guardian_user_id
    belongs_to :student,  class_name: "GroupManagement::Student"
    belongs_to :created_by, class_name: "Core::InstitutionUser", optional: true

    scope :active, -> { where(status: "active") }
  end
end
