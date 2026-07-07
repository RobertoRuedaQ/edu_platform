module TeacherManagement
  class TeachersController < ApplicationController
    def index
      authorize!("teachers.view")
      @teachers = TeacherManagement::TeacherScope.new(context: authorization_context).resolve
    end

    def show
      @teacher = TeacherManagement::TeacherRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("teachers.view", @teacher)
    end
  end
end
