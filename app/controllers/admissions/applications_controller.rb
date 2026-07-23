module Admissions
  class ApplicationsController < ApplicationController
    before_action :set_application, only: %i[show update]

    def index
      authorize!("admissions.applications.manage")
      @applications = Admissions::ApplicationScope.new(context: authorization_context).resolve
    end

    def show
      authorize!("admissions.applications.manage", @application)
      @steps = @application.application_steps.includes(:step_template, :evaluator)
        .order("admission_step_templates.position")
    end

    def create
      authorize!("admissions.intake")
      applicant = Admissions::Applicant.find_by!(institution_id: Current.institution_id, id: params[:applicant_id])
      campaign = Admissions::Campaign.find_by!(institution_id: Current.institution_id, id: params[:campaign_id])
      target_grade_level = GroupManagement::GradeLevel.find_by!(institution_id: Current.institution_id,
        id: params[:target_grade_level_id])

      Admissions::ApplicationSubmitter.call(institution: Current.institution, applicant: applicant,
        campaign: campaign, target_grade_level: target_grade_level, idempotency_key: params[:idempotency_key])
      redirect_to admissions_applicant_path(applicant), notice: "Solicitud radicada."
    end

    # Transiciones de solo-revisión (under_review/rejected/withdrawn) — un
    # simple update, molde Cafeteria::MenuController (authorize! es el único
    # portón). "accepted" es rechazado aquí a propósito, molde
    # Library::ResourceCopiesController: esa transición SOLO ocurre vía
    # Admissions::AcceptanceConverter (crea el estudiante real + cobra la
    # cuota), nunca un edit de estado suelto.
    def update
      authorize!("admissions.applications.manage", @application)
      new_status = params.require(:application).permit(:status)[:status]

      if new_status == "accepted"
        redirect_to admissions_application_path(@application),
          alert: "Para aceptar, usa el flujo de conversión (crea el estudiante y cobra la cuota)."
        return
      end

      if @application.update(status: new_status)
        redirect_to admissions_application_path(@application), notice: "Solicitud actualizada."
      else
        redirect_to admissions_application_path(@application), alert: @application.errors.full_messages.to_sentence
      end
    end

    private

    def set_application
      @application = Admissions::Application.find_by!(institution_id: Current.institution_id, id: params[:id])
    end
  end
end
