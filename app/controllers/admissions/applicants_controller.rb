module Admissions
  # Registro de aspirantes (mostrador) — molde Library::ResourcesController:
  # sin query object, institución-wide.
  class ApplicantsController < ApplicationController
    def index
      authorize!("admissions.intake")
      @applicants = Admissions::Applicant.where(institution_id: Current.institution_id).order(:last_name)
    end

    def new
      authorize!("admissions.intake")
      @applicant = Admissions::Applicant.new
    end

    def create
      authorize!("admissions.intake")
      @applicant = Admissions::Applicant.new(applicant_params.merge(institution: Current.institution))
      if @applicant.save
        redirect_to admissions_applicant_path(@applicant), notice: "Aspirante registrado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # También el punto de entrada para radicar la solicitud del aspirante y
    # adjuntar documentos (formularios embebidos, molde
    # assignments/_submission_form.html.erb: dos form_with independientes en
    # la misma página).
    def show
      authorize!("admissions.intake")
      @applicant = Admissions::Applicant.find_by!(institution_id: Current.institution_id, id: params[:id])
      @open_campaigns = Admissions::Campaign.open.where(institution_id: Current.institution_id)
      @grade_levels = GroupManagement::GradeLevel.where(institution_id: Current.institution_id).order(:level_number)
      @applications = @applicant.applications.includes(:campaign, :target_grade_level).order(submitted_at: :desc)
    end

    private

    def applicant_params
      params.require(:applicant).permit(:first_name, :last_name, :gender, :birthdate, :guardian_name,
        :guardian_email, :guardian_phone)
    end
  end
end
