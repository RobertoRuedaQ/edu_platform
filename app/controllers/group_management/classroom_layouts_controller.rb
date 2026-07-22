module GroupManagement
  # Reconfiguration surface for a group's physical classroom layout
  # (BI_DOCUMENT.md §5.3, Slice 2). group_management OWNS classroom_layouts/
  # seat_assignments (decision A2), so the WRITE lives here, gated by the
  # existing groups.manage permission (managing the physical classroom is the
  # same capability as managing a group's roster — see MembershipsController).
  # analytics_bi only READS these tables for the Lens 1 heat map.
  #
  # A single "apply configuration" POST both OPENS the first layout and
  # RECONFIGURES an existing one — GroupManagement::ClassroomReconfigurer closes
  # the current version (append-only) and opens version + 1.
  class ClassroomLayoutsController < ApplicationController
    def show
      @group = find_group
      authorize!("groups.manage", @group)
      @term = active_term
      @layout = current_layout
      @assignments = active_assignments
      @seated_ids = @assignments.map(&:student_id).to_set
      @unseated = @group.students.where.not(id: @seated_ids).order(:last_name, :first_name).to_a
    end

    def create
      @group = find_group
      authorize!("groups.manage", @group)
      term = active_term
      return redirect_to(group_management_group_classroom_layout_path(@group), alert: "No hay un término activo.") if term.nil?

      GroupManagement::ClassroomReconfigurer.call(section: @group, academic_term: term,
        rows: layout_params[:rows].to_i, cols: layout_params[:cols].to_i,
        board_orientation: layout_params[:board_orientation].to_i)
      redirect_to group_management_group_classroom_layout_path(@group), notice: "Distribución del aula aplicada."
    end

    private

    def find_group
      group = GroupManagement::Section.find_by(institution_id: Current.institution_id, id: params[:group_id])
      raise ActiveRecord::RecordNotFound if group.nil?

      group
    end

    def active_term
      Core::AcademicTerm.active.where(institution_id: Current.institution_id).first
    end

    def current_layout
      return nil if @term.nil?

      GroupManagement::ClassroomLayout
        .where(institution_id: Current.institution_id, section_id: @group.id, academic_term_id: @term.id)
        .current
        .first
    end

    def active_assignments
      return [] if @layout.nil?

      GroupManagement::SeatAssignment
        .where(institution_id: Current.institution_id, classroom_layout_id: @layout.id)
        .active
        .includes(:student)
        .to_a
    end

    def layout_params
      params.require(:classroom_layout).permit(:rows, :cols, :board_orientation)
    end
  end
end
