module GroupManagement
  class StudentsController < ApplicationController
    def index
      authorize!("students.read")
      @students = GroupManagement::StudentScope.new(context: authorization_context).resolve
    end

    def show
      @student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @student.nil?

      authorize!("students.read", @student)
    end
  end
end
