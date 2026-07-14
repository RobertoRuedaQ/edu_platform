module TeacherManagement
  class TeachersController < ApplicationController
    def index
      authorize!("teachers.view")
      @teachers = TeacherManagement::TeacherScope.new(context: authorization_context).resolve
    end

    def show
      @teacher = TeacherManagement::Teacher.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @teacher.nil?

      authorize!("teachers.view", @teacher)
    end
  end
end
