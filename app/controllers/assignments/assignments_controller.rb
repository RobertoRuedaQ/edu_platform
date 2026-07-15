module Assignments
  # Create/edit/publish/archive/grade — molde #4, scoped to the subject
  # (same institution-wide-or-grade_level RBAC as Schedules::
  # GradeEntriesController already uses for grades.write). Grading writes
  # directly to the fanned-out schedules::Assessment rows
  # (Assignments::GradeRecorder) — never a second store on this model.
  class AssignmentsController < ApplicationController
    def index
      @subject = find_subject
      authorize!("assignment.manage", @subject)
      @assignments = Assignments::Assignment.where(institution_id: Current.institution_id, subject_id: @subject.id)
        .order(due_date: :desc)
    end

    def new
      @subject = find_subject
      authorize!("assignment.manage", @subject)
      @assignment = Assignments::Assignment.new
    end

    def create
      @subject = find_subject
      authorize!("assignment.manage", @subject)
      @assignment = Assignments::Assignment.new(assignment_params)
      @assignment.institution = Current.institution
      @assignment.subject = @subject
      @assignment.created_by_institution_user_id = Current.institution_user_id
      @assignment.status = "draft"

      if @assignment.save
        redirect_to assignments_subject_assignment_path(@subject, @assignment), notice: "Tarea creada como borrador."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)
    end

    def update
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)

      if @assignment.update(assignment_params)
        redirect_to assignments_subject_assignment_path(@subject, @assignment), notice: "Tarea actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def show
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)
      @roster = Assignments::Roster.for_subject(@subject).order(:last_name, :first_name)
      @scores = if @assignment.published?
        Schedules::Assessment.joins(:enrollment)
          .where(assignment_id: @assignment.id)
          .index_by { |assessment| assessment.enrollment.student_id }
      else
        {}
      end
    end

    def publish
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)
      Assignments::Publisher.call(@assignment) if @assignment.draft?
      redirect_to assignments_subject_assignment_path(@subject, @assignment), notice: "Tarea publicada."
    end

    def archive
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)
      @assignment.update!(status: "archived") if @assignment.published?
      redirect_to assignments_subject_assignments_path(@subject), notice: "Tarea archivada."
    end

    def destroy
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)

      if @assignment.draft?
        @assignment.destroy!
        redirect_to assignments_subject_assignments_path(@subject), notice: "Borrador eliminado."
      else
        redirect_to assignments_subject_assignment_path(@subject, @assignment),
          alert: "Solo un borrador se puede eliminar — una tarea publicada se archiva."
      end
    end

    def grade
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)

      unless @assignment.published?
        redirect_to assignments_subject_assignment_path(@subject, @assignment),
          alert: "Solo una tarea publicada tiene notas — publícala primero."
        return
      end

      (params[:scores] || {}).to_unsafe_h.each do |student_id, score|
        next if score.blank?

        student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: student_id)
        next if student.nil?

        Assignments::GradeRecorder.call(assignment: @assignment, student: student, score: score)
      end

      redirect_to assignments_subject_assignment_path(@subject, @assignment), notice: "Notas guardadas."
    end

    private

    def find_subject
      subject = Schedules::Subject.find_by(institution_id: Current.institution_id, id: params[:subject_id])
      raise ActiveRecord::RecordNotFound if subject.nil?

      subject
    end

    def find_assignment
      assignment = Assignments::Assignment.find_by(institution_id: Current.institution_id, subject_id: @subject.id,
        id: params[:id])
      raise ActiveRecord::RecordNotFound if assignment.nil?

      assignment
    end

    def assignment_params
      params.require(:assignment).permit(:title, :instructions, :due_date)
    end
  end
end
