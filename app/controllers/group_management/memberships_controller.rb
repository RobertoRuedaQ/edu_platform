module GroupManagement
  # Assigns/removes students from a group's roster. groups.manage is a
  # distinct, narrower permission than groups.view: seeing a group's roster
  # and editing who's on it are different capabilities (homeroom/coordinator/
  # secretary per Apéndice A, not every role that can view groups).
  class MembershipsController < ApplicationController
    def edit
      @group = find_group
      authorize!("groups.manage", @group)
      @roster = @group.students.order(:last_name, :first_name).to_a
      @roster_ids = @roster.map(&:id).to_set
      @available = GroupManagement::Student
        .where(institution_id: Current.institution_id)
        .where.not(id: @roster_ids)
        .order(:last_name, :first_name)
        .to_a
    end

    # #4 barrido: students.section_id is a real column (no target model
    # missing, unlike teacher.evaluate) — so unlike that gate-only action,
    # this one persists for real. Checked students are placed in @group;
    # anyone previously in @group but unchecked is set back to unassigned
    # (section_id: nil), never silently left in a group they were removed
    # from.
    def update
      @group = find_group
      authorize!("groups.manage", @group)

      submitted_ids = Array(params[:student_ids])
      GroupManagement::Student
        .where(institution_id: Current.institution_id, section_id: @group.id)
        .where.not(id: submitted_ids)
        .update_all(section_id: nil)
      GroupManagement::Student
        .where(institution_id: Current.institution_id, id: submitted_ids)
        .update_all(section_id: @group.id)

      redirect_to group_management_group_path(@group.id), notice: "Matrícula del grupo actualizada."
    end

    private

    def find_group
      group = GroupManagement::Section.find_by(institution_id: Current.institution_id, id: params[:group_id])
      raise ActiveRecord::RecordNotFound if group.nil?

      group
    end
  end
end
