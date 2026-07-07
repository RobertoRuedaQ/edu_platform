module TeacherManagement
  class DepartmentsController < ApplicationController
    def index
      authorize!("departments.view")
      @departments = TeacherManagement::DepartmentScope.new(context: authorization_context).resolve
    end

    def show
      @department = TeacherManagement::DepartmentRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("departments.view", @department)
      @teachers = TeacherManagement::TeacherRoster.for_department(@department.id)
    end
  end
end
