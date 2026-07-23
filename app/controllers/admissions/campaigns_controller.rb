module Admissions
  # Ciclos de admisión — molde Library::ResourcesController: sin query
  # object (institución-wide, nada que filtrar por fila).
  class CampaignsController < ApplicationController
    before_action :set_campaign, only: %i[edit update]

    def index
      authorize!("admissions.campaigns.manage")
      @campaigns = Admissions::Campaign.where(institution_id: Current.institution_id).order(opens_on: :desc)
    end

    def new
      authorize!("admissions.campaigns.manage")
      @campaign = Admissions::Campaign.new
    end

    def create
      authorize!("admissions.campaigns.manage")
      @campaign = Admissions::Campaign.new(campaign_params.merge(institution: Current.institution))
      if @campaign.save
        redirect_to admissions_campaigns_path, notice: "Campaña creada."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize!("admissions.campaigns.manage")
    end

    def update
      authorize!("admissions.campaigns.manage")
      if @campaign.update(campaign_params)
        redirect_to admissions_campaigns_path, notice: "Campaña actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_campaign
      @campaign = Admissions::Campaign.find_by!(institution_id: Current.institution_id, id: params[:id])
    end

    def campaign_params
      params.require(:campaign).permit(:name, :target_entry_year, :opens_on, :closes_on, :status,
        :application_fee_cents)
    end
  end
end
