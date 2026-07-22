module StudentSupport
  # Apéndice A gives one unified role list for "pestaña + create" (homeroom,
  # coexistence_coordinator, counselor, coordinator, principal) — no read/write
  # split like accommodations/medical_history, so one permission covers both.
  #
  # REAL as of guidelines/CLOSURE_PLAN.md Fase B — StudentSupport::
  # DisciplinaryLog replaces the DisciplinaryLogRoster stub (hardcoded fake
  # rows, #create was a literal no-op). find_student now resolves the REAL
  # GroupManagement::Student directly (GroupManagement::StudentRoster is
  # retired from this controller per its own retirement note: "retire it once
  # those domains get their own real-data slice").
  class DisciplinaryLogsController < ApplicationController
    def index
      @student = find_student
      authorize!("disciplinary_logs.manage", @student)
      @logs = StudentSupport::DisciplinaryLog
        .where(institution_id: Current.institution_id, student_id: @student.id)
        .includes(reported_by: :user)
        .order(occurred_at: :desc)
    end

    # Append-only: a disciplinary log is immutable once created (no
    # update/destroy route) — a correction is a NEW entry, never an edit to
    # history. Audited (§3.1: sensitive, Class S) — every write is traceable to
    # the reporting staff member via reported_by_institution_user_id, and also
    # logged to audit_events for the cross-cutting audit viewer.
    def create
      @student = find_student
      authorize!("disciplinary_logs.manage", @student)

      log = StudentSupport::DisciplinaryLog.new(log_params.merge(
        institution_id: Current.institution_id, student: @student, reported_by: Current.institution_user
      ))
      if log.save
        IdentityAccess::Audit.log(
          institution: Current.institution, action: "disciplinary_log.recorded",
          actor_institution_user: Current.institution_user, target: log,
          metadata: { student_id: @student.id, category: log.category }
        )
        redirect_to student_support_student_disciplinary_logs_path(@student.id), notice: "Registro de convivencia guardado."
      else
        @logs = StudentSupport::DisciplinaryLog
          .where(institution_id: Current.institution_id, student_id: @student.id)
          .includes(reported_by: :user).order(occurred_at: :desc)
        @log = log
        render :index, status: :unprocessable_entity
      end
    end

    private

    def find_student
      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
      raise ActiveRecord::RecordNotFound if student.nil?

      student
    end

    def log_params
      params.permit(:category, :description, :occurred_at)
    end
  end
end
