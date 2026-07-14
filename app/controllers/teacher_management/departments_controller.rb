module TeacherManagement
  class DepartmentsController < ApplicationController
    def index
      authorize!("departments.view")
      @departments = TeacherManagement::DepartmentScope.new(context: authorization_context).resolve
      @teacher_counts = TeacherManagement::Teacher
        .joins(:staff_member)
        .where(institution_id: Current.institution_id, staff_members: { department_id: @departments.map(&:id) })
        .group("staff_members.department_id")
        .count
    end

    def show
      @department = StaffManagement::Department.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @department.nil?

      authorize!("departments.view", @department)
      @teachers = TeacherManagement::Teacher
        .joins(:staff_member)
        .where(institution_id: Current.institution_id, staff_members: { department_id: @department.id })
        .order(:last_name, :first_name)
    end
  end
end
