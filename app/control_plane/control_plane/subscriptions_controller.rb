# frozen_string_literal: true

module ControlPlane
  # Nested under institutions/:institution_id/subscriptions — same shape as
  # PlanPriceTiersController nested under plans. No index/edit/destroy: the
  # institution's own show page is the history view, and a signed
  # subscription's terms are immutable (F15) — "editing" means #terminate
  # this one and sign a new one.
  class SubscriptionsController < BaseController
    before_action :set_institution
    before_action :set_subscription, only: %i[show terminate]

    def new
      authorize_platform!("billing.manage")
      @subscription = Subscription.new
      @plans = Plan.active.order(:name)
    end

    def create
      authorize_platform!("billing.manage")
      plan = Plan.active.find_by(id: subscription_params[:plan_id])
      if plan.nil?
        @subscription = Subscription.new
        @plans = Plan.active.order(:name)
        flash.now[:alert] = "Selecciona un plan activo."
        return render :new, status: :unprocessable_entity
      end

      @subscription = Subscription.sign!(institution: @institution, plan: plan,
        starts_on: subscription_params[:starts_on].presence || Date.current)
      ControlPlane::Audit.log(action: "subscription.signed", platform_admin: current_platform_admin,
        target: @subscription, metadata: { institution_id: @institution.id, plan_key: plan.key },
        ip_address: request.remote_ip)
      redirect_to control_plane_institution_path(@institution), notice: "Suscripción firmada."
    rescue ActiveRecord::RecordInvalid => e
      @subscription = e.record
      @plans = Plan.active.order(:name)
      render :new, status: :unprocessable_entity
    end

    def show
    end

    def terminate
      authorize_platform!("billing.manage")
      @subscription.end!
      ControlPlane::Audit.log(action: "subscription.ended", platform_admin: current_platform_admin,
        target: @subscription, metadata: { institution_id: @institution.id }, ip_address: request.remote_ip)
      redirect_to control_plane_institution_path(@institution), notice: "Suscripción terminada."
    rescue ActiveRecord::RecordInvalid
      redirect_to control_plane_institution_path(@institution),
        alert: "No se puede terminar una suscripción el mismo día en que empezó — espera al día siguiente."
    end

    private

    def set_institution
      @institution = Core::Institution.find(params[:institution_id])
    end

    def set_subscription
      @subscription = Subscription.where(institution_id: @institution.id).find(params[:id])
    end

    def subscription_params
      params.fetch(:subscription, {}).permit(:plan_id, :starts_on)
    end
  end
end
