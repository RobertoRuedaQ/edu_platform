module GroupManagement
  # Assign/move (create) and unassign (destroy) a student's seat within a
  # group's current ClassroomLayout (BI_DOCUMENT.md §5.3, Slice 2). gated by
  # groups.manage, same as ClassroomLayoutsController. Append-only: a move
  # closes the old seat and opens a new one (GroupManagement::SeatAssigner); an
  # unassign closes the active seat. Double-booking is rejected by the DB
  # exclusion constraint (StatementInvalid) and surfaced as a friendly alert,
  # never a 500.
  class SeatAssignmentsController < ApplicationController
    def create
      @group = find_group
      authorize!("groups.manage", @group)
      layout = current_layout
      return redirect_back_with("No hay una distribución de aula vigente.") if layout.nil?

      student = find_student
      GroupManagement::SeatAssigner.call(layout: layout, student: student,
        row: params[:row].to_i, col: params[:col].to_i)
      redirect_to group_management_group_classroom_layout_path(@group), notice: "Asiento asignado."
    rescue ActiveRecord::StatementInvalid
      redirect_back_with("Ese asiento ya está ocupado por otro estudiante.")
    end

    def destroy
      @group = find_group
      authorize!("groups.manage", @group)
      layout = current_layout
      student = find_student(params[:id])
      GroupManagement::SeatAssigner.unassign(layout: layout, student: student) if layout
      redirect_to group_management_group_classroom_layout_path(@group), notice: "Asiento liberado."
    end

    private

    def find_group
      group = GroupManagement::Section.find_by(institution_id: Current.institution_id, id: params[:group_id])
      raise ActiveRecord::RecordNotFound if group.nil?

      group
    end

    def find_student(id = params[:student_id])
      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: id)
      raise ActiveRecord::RecordNotFound if student.nil?

      student
    end

    def current_layout
      term = Core::AcademicTerm.active.where(institution_id: Current.institution_id).first
      return nil if term.nil?

      GroupManagement::ClassroomLayout
        .where(institution_id: Current.institution_id, section_id: @group.id, academic_term_id: term.id)
        .current
        .first
    end

    def redirect_back_with(message)
      redirect_to group_management_group_classroom_layout_path(@group), alert: message
    end
  end
end
