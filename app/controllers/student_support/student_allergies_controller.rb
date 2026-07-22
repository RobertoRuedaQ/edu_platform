module StudentSupport
  # Minimal write path for StudentAllergy (guidelines/CLOSURE_PLAN.md Fase D)
  # — new/create only, no edit/destroy (an allergy correction is a new entry;
  # this mirrors disciplinary_logs' append-only-by-absence-of-route posture).
  # Gated by the FULL tier (medical_history.view) — the narrow counselor tier
  # (medical_history.view_summary) may READ allergies but never author them.
  class StudentAllergiesController < ApplicationController
    def new
      @student = find_student
      authorize!("medical_history.view", @student)
      @allergy = StudentSupport::StudentAllergy.new
    end

    def create
      @student = find_student
      authorize!("medical_history.view", @student)
      @allergy = StudentSupport::StudentAllergy.new(allergy_params.merge(
        institution_id: Current.institution_id, student: @student
      ))
      if @allergy.save
        redirect_to student_support_student_medical_history_path(@student.id), notice: "Alergia registrada."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def find_student
      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
      raise ActiveRecord::RecordNotFound if student.nil?

      student
    end

    def allergy_params
      params.require(:student_allergy).permit(:allergen_name, :severity, :reaction)
    end
  end
end
