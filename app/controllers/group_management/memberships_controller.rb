module GroupManagement
  # Assigns/removes students from a group's roster. groups.manage is a
  # distinct, narrower permission than groups.view: seeing a group's roster
  # and editing who's on it are different capabilities (homeroom/coordinator/
  # secretary per Apéndice A, not every role that can view groups).
  class MembershipsController < ApplicationController
    def edit
      @group = find_group
      authorize!("groups.manage", @group)
      @roster = GroupManagement::StudentRoster.for_group(@group.id)
      @available = GroupManagement::StudentRoster.all - @roster
    end

    def update
      @group = find_group
      authorize!("groups.manage", @group)

      # STUB: no persistence yet. TODO: reemplazar por UPDATE real de students.section_id.
      flash[:notice] = "Matrícula del grupo actualizada (stub)."
      redirect_to group_management_group_path(@group.id)
    end

    private

    def find_group
      GroupManagement::GroupRoster.find(params[:group_id]) or raise ActiveRecord::RecordNotFound
    end
  end
end
