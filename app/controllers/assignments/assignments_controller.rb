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
      @rubric_templates = own_rubric_templates
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
      @rubric_templates = own_rubric_templates
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
      # Assignments::GradingView pairs roster + grade + submission in ONE
      # place (v1.22.0) — before publish there's nothing fanned-out yet, so
      # the preview roster has no grades/submissions to pair (grading and
      # submitting only make sense against a published assignment).
      @rows = @assignment.published? ? Assignments::GradingView.for(@assignment) : []
      @roster = Assignments::Roster.for_subject(@subject).order(:last_name, :first_name)

      # Draft reads the LIVE template (same "draft reads live, publish
      # freezes" split as report_cards) — published reads ONLY the frozen
      # snapshot, never the live library again (v1.26.0).
      if @assignment.rubric?
        @rubric_view = @assignment.published? ? @assignment.rubric_snapshot : @assignment.rubric_template&.snapshot
        @rubric_evaluations_by_student = Assignments::RubricEvaluation.where(assignment: @assignment)
          .index_by { |e| e.student_id || e.submission_group_id } if @assignment.published?
      end

      if @assignment.group_work? && @assignment.published?
        @groups = @assignment.submission_groups.includes(:students, :submission).order(:name)
        grouped_ids = Assignments::GroupMembership.where(assignment_id: @assignment.id).select(:student_id)
        @unassigned = @roster.where.not(id: grouped_ids)
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

      if @assignment.rubric?
        grade_by_rubric
      else
        grade_directly
      end

      redirect_to assignments_subject_assignment_path(@subject, @assignment), notice: "Notas guardadas."
    end

    private

    # Group bulk-set FIRST, then per-student overrides — so a teacher who
    # fills both a group score AND a specific student's box in the SAME
    # submit gets the override to win (matches "calificar grupo... el
    # docente puede luego modificar la nota de un integrante", §0.2).
    def grade_directly
      (params[:group_scores]&.to_unsafe_h || {}).each do |group_id, score|
        next if score.blank?

        group = Assignments::SubmissionGroup.find_by(institution_id: Current.institution_id,
          assignment_id: @assignment.id, id: group_id)
        next if group.nil?

        Assignments::GroupGrader.call(assignment: @assignment, submission_group: group, score: score)
      end

      (params[:scores]&.to_unsafe_h || {}).each do |student_id, score|
        next if score.blank?

        student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: student_id)
        next if student.nil?

        Assignments::GradeRecorder.call(assignment: @assignment, student: student, score: score)
      end
    end

    # Same "group first, then per-student override" ordering as direct
    # grading — a rubric evaluation for one member overrides the group's
    # shared one exactly like a direct score override would.
    def grade_by_rubric
      (params[:group_rubric_evaluations]&.to_unsafe_h || {}).each do |group_id, levels_by_criterion|
        next if levels_by_criterion.blank?

        group = Assignments::SubmissionGroup.find_by(institution_id: Current.institution_id,
          assignment_id: @assignment.id, id: group_id)
        next if group.nil?

        Assignments::GroupRubricGrader.call(assignment: @assignment, submission_group: group,
          levels_by_criterion: levels_by_criterion, evaluated_by: Current.user)
      end

      (params[:rubric_evaluations]&.to_unsafe_h || {}).each do |student_id, levels_by_criterion|
        next if levels_by_criterion.blank?

        student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: student_id)
        next if student.nil?

        Assignments::RubricGrader.call(assignment: @assignment, student: student,
          levels_by_criterion: levels_by_criterion, evaluated_by: Current.user)
      end
    end

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
      # group_work/evaluation_method/rubric_template_id are only EVER
      # effective while draft — Assignment's own before_validations
      # (lock_group_work_after_publish, lock_evaluation_method_after_publish)
      # discard any change once published, regardless of what's submitted here.
      params.require(:assignment).permit(:title, :instructions, :due_date, :group_work, :evaluation_method,
        :rubric_template_id)
    end

    def own_rubric_templates
      Assignments::RubricTemplate.where(institution_id: Current.institution_id, authored_by_user_id: Current.user.id)
        .order(:name)
    end
  end
end
