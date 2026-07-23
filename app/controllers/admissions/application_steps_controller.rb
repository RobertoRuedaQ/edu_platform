module Admissions
  # Actualiza el estado/notas/evaluador de UN paso de UNA solicitud
  # (guidelines/library_prompt.md, Increment 3) — reusa
  # admissions.applications.manage (revisar/decidir), sin permiso nuevo.
  # private_notes/evaluator viven SOLO aquí, en el lado staff — el tracker
  # público (Admissions::Tracker::PublicView) nunca los toca.
  class ApplicationStepsController < ApplicationController
    def update
      application = Admissions::Application.find_by!(institution_id: Current.institution_id,
        id: params[:application_id])
      authorize!("admissions.applications.manage", application)
      step = application.application_steps.find(params[:id])

      if step.update(step_params)
        redirect_to admissions_application_path(application), notice: "Paso actualizado."
      else
        redirect_to admissions_application_path(application), alert: step.errors.full_messages.to_sentence
      end
    end

    private

    def step_params
      params.require(:application_step).permit(:status, :private_notes, :evaluator_institution_user_id)
    end
  end
end
