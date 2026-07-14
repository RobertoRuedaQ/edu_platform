module StudentSupport
  # Tutor/acudiente. Both genders. School students may have up to 2.
  class Guardian < ApplicationRecord
    self.table_name = "guardians"

    belongs_to :institution, class_name: "Core::Institution"
    has_many :student_guardians, class_name: "StudentSupport::StudentGuardian",
             foreign_key: :guardian_id, inverse_of: :guardian, dependent: :destroy
    has_many :students, through: :student_guardians, source: :student

    validates :first_name, :last_name, :gender, presence: true
  end
end
