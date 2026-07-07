module TeacherManagement
  # ACCEPTANCE CASE for the role+scope mechanism: only an actor holding
  # teacher.evaluate scoped to the teacher's OWN department may evaluate them
  # (e.g. an area_lead over their department's teachers, never the rest of
  # the institution). authorize! is the real gate; the "Evaluar" button in
  # teachers#show is only ever cosmetically shown via can?.
  class TeacherEvaluationsController < ApplicationController
    def new
      @teacher = find_teacher
      authorize!("teacher.evaluate", @teacher)
    end

    def create
      @teacher = find_teacher
      authorize!("teacher.evaluate", @teacher)

      # STUB: no persistence yet. TODO: reemplazar por TeacherManagement::Evaluation real.
      flash[:notice] = "Evaluación registrada (stub) para #{@teacher.name}."
      redirect_to teacher_management_teacher_path(@teacher.id)
    end

    private

    def find_teacher
      TeacherManagement::TeacherRoster.find(params[:teacher_id]) or raise ActiveRecord::RecordNotFound
    end
  end
end
