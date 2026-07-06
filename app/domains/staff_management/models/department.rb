module StaffManagement
  class Department < ApplicationRecord
    self.table_name = "departments"
    belongs_to :institution, class_name: "Core::Institution"
    has_many :staff_members, class_name: "StaffManagement::StaffMember",
             foreign_key: :department_id, inverse_of: :department, dependent: :nullify
    validates :name, :code, :kind, presence: true
  end
end
