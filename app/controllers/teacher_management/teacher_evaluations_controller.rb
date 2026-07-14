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

      # BV6 (#4 slice 1): no TeacherManagement::Evaluation model exists yet,
      # so there is nothing real to persist here — this slice's job was the
      # GATE (authorize! + can?, now over a real Teacher/department_id, not
      # the stub), not a new evaluation workflow. Building the real model is
      # follow-up, not invented here.
      flash[:notice] = "Evaluación registrada (stub) para #{@teacher.first_name} #{@teacher.last_name}."
      redirect_to teacher_management_teacher_path(@teacher.id)
    end

    private

    def find_teacher
      teacher = TeacherManagement::Teacher.find_by(institution_id: Current.institution_id, id: params[:teacher_id])
      raise ActiveRecord::RecordNotFound if teacher.nil?

      teacher
    end
  end
end
