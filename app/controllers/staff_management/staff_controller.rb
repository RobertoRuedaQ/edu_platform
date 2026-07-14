module StaffManagement
  # "Personal" — the staff directory, scope-filtered same as teacher_management
  # (#4 slice 1's canonical pattern; see StaffScope). institution_admin's
  # institution-wide grant sees everyone incl. non-academic staff
  # (department_id nil); a department-scoped grant (e.g. area_lead) sees only
  # their own department's roster.
  class StaffController < ApplicationController
    def index
      authorize!("staff.read")
      @staff = StaffManagement::StaffScope.new(context: authorization_context).resolve
    end
  end
end
