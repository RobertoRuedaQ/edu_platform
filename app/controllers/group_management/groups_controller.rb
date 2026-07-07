module GroupManagement
  class GroupsController < ApplicationController
    def index
      authorize!("groups.view")
      @groups = GroupManagement::GroupScope.new(context: authorization_context).resolve
    end

    def show
      @group = GroupManagement::GroupRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("groups.view", @group)
      @students = GroupManagement::StudentRoster.for_group(@group.id)
    end
  end
end
