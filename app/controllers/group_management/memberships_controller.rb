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
    #
    # Slice 4 (BI_DOCUMENT.md §5.2): the two former bulk update_all calls are
    # replaced by per-student GroupManagement::SectionReassigner calls — THE
    # single write seam that keeps students.section_id (the live cache) and the
    # append-only student_placements history in lock-step. The roster of one
    # homeroom is small (~30-40), so per-row is fine, and it keeps ALL
    # placement-closing logic in one place (never scattered across call sites).
    # SectionReassigner is idempotent, so a resubmit of the same roster never
    # churns placement history.
    def update
      @group = find_group
      authorize!("groups.manage", @group)

      submitted_ids = Array(params[:student_ids])
      GroupManagement::Student
        .where(institution_id: Current.institution_id, section_id: @group.id)
        .where.not(id: submitted_ids)
        .find_each { |student| GroupManagement::SectionReassigner.call(student: student, section: nil) }
      GroupManagement::Student
        .where(institution_id: Current.institution_id, id: submitted_ids)
        .find_each { |student| GroupManagement::SectionReassigner.call(student: student, section: @group) }

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
