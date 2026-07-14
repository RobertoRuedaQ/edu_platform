module StaffManagement
  class EmploymentPeriod < ApplicationRecord
    self.table_name = "employment_periods"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :staff_member, class_name: "StaffManagement::StaffMember",
               inverse_of: :employment_periods
    validates :contract_type, :starts_on, :status, presence: true
  end
end
