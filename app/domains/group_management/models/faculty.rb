module GroupManagement
  # University academic unit (e.g. Ingeniería, Ciencias Sociales).
  class Faculty < ApplicationRecord
    self.table_name = "faculties"

    belongs_to :institution, class_name: "Core::Institution"
    has_many :programs, class_name: "GroupManagement::Program",
             foreign_key: :faculty_id, inverse_of: :faculty, dependent: :destroy

    validates :name, :code, presence: true
  end
end
