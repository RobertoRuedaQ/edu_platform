module GroupManagement
  # University program of study (e.g. Historia, Ingeniería de Sistemas).
  class Program < ApplicationRecord
    self.table_name = "programs"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :faculty, class_name: "GroupManagement::Faculty", inverse_of: :programs
    has_many :students, class_name: "GroupManagement::Student",
             foreign_key: :program_id, inverse_of: :program

    validates :name, :code, presence: true
  end
end
