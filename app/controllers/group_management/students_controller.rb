module GroupManagement
  class StudentsController < ApplicationController
    def index
      authorize!("students.read")
      @students = GroupManagement::StudentScope.new(context: authorization_context).resolve
    end

    def show
      @student = GroupManagement::StudentRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("students.read", @student)
    end
  end
end
