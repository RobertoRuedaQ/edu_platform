module GroupManagement
  class GroupsController < ApplicationController
    def index
      authorize!("groups.view")
      @groups = GroupManagement::GroupScope.new(context: authorization_context).resolve
      @student_counts = GroupManagement::Student
        .where(institution_id: Current.institution_id, section_id: @groups.map(&:id))
        .group(:section_id).count
    end

    def show
      @group = GroupManagement::Section.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @group.nil?

      authorize!("groups.view", @group)
      @students = @group.students.order(:last_name, :first_name)
    end
  end
end
