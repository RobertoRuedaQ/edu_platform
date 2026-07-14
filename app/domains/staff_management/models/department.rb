module StaffManagement
  class Department < ApplicationRecord
    self.table_name = "departments"
    belongs_to :institution, class_name: "Core::Institution"
    has_many :staff_members, class_name: "StaffManagement::StaffMember",
             foreign_key: :department_id, inverse_of: :department, dependent: :nullify
    validates :name, :code, :kind, presence: true

    # Scope-covering descriptor (Authorization::Assignment::SCOPE_READERS
    # reads resource.department_id for a :department-scoped grant) — a
    # department resource IS its own department_id, same trick the old
    # in-memory DepartmentRoster::Row used before this became real (#4
    # slice 1).
    def department_id
      id
    end
  end
end
