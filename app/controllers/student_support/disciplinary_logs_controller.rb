module StudentSupport
  # Apéndice A gives one unified role list for "pestaña + create" (homeroom,
  # coexistence_coordinator, counselor, coordinator, principal) — no read/write
  # split like accommodations/medical_history, so one permission covers both.
  class DisciplinaryLogsController < ApplicationController
    def index
      @student = find_student
      authorize!("disciplinary_logs.manage", @student)
      @logs = StudentSupport::DisciplinaryLogRoster.for_student(@student.id)
    end

    def create
      @student = find_student
      authorize!("disciplinary_logs.manage", @student)

      # STUB: no persistence yet. TODO: reemplazar por un modelo real.
      flash[:notice] = "Registro de convivencia guardado (stub)."
      redirect_to group_management_student_path(@student.id)
    end

    private

    def find_student
      GroupManagement::StudentRoster.find(params[:student_id]) or raise ActiveRecord::RecordNotFound
    end
  end
end
