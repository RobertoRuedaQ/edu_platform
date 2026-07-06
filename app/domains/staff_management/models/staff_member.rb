module StaffManagement
  class StaffMember < ApplicationRecord
    self.table_name = "staff_members"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :institution_user, class_name: "Core::InstitutionUser"
    belongs_to :department, class_name: "StaffManagement::Department",
               optional: true, inverse_of: :staff_members
    has_many :employment_periods, class_name: "StaffManagement::EmploymentPeriod",
             foreign_key: :staff_member_id, inverse_of: :staff_member, dependent: :destroy
    # A teaching staff member is extended by teacher_management (D1).
    has_one :teacher, class_name: "TeacherManagement::Teacher",
            foreign_key: :staff_member_id, inverse_of: :staff_member, dependent: :nullify

    validates :employee_number, :staff_category, :employment_type, :status, presence: true
  end
end
