module Admissions
  # Pasos configurables de una campaña (guidelines/library_prompt.md,
  # Increment 3) — molde Library::ResourceCopiesController: nested,
  # institution-wide, sin query object. Reusa admissions.campaigns.manage
  # (config de campaña), sin permiso nuevo.
  class StepTemplatesController < ApplicationController
    before_action :set_campaign

    def index
      authorize!("admissions.campaigns.manage")
      @step_templates = @campaign.step_templates
    end

    def new
      authorize!("admissions.campaigns.manage")
      @step_template = @campaign.step_templates.new
    end

    def create
      authorize!("admissions.campaigns.manage")
      @step_template = @campaign.step_templates.new(step_template_params.merge(institution: Current.institution))
      if @step_template.save
        redirect_to admissions_campaign_step_templates_path(@campaign), notice: "Paso agregado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize!("admissions.campaigns.manage")
      @step_template = @campaign.step_templates.find(params[:id])
    end

    def update
      authorize!("admissions.campaigns.manage")
      @step_template = @campaign.step_templates.find(params[:id])
      if @step_template.update(step_template_params)
        redirect_to admissions_campaign_step_templates_path(@campaign), notice: "Paso actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_campaign
      @campaign = Admissions::Campaign.find_by!(institution_id: Current.institution_id, id: params[:campaign_id])
    end

    def step_template_params
      params.require(:step_template).permit(:name, :position, :description)
    end
  end
end
