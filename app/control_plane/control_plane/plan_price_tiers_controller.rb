# frozen_string_literal: true

module ControlPlane
  # Nested under plans/:plan_id/price_tiers. Tiers are hard-deletable (live
  # plan config, not referenced by historical invoices) — see
  # ControlPlane::PlanPriceTier.
  class PlanPriceTiersController < BaseController
    before_action :set_plan
    before_action :set_price_tier, only: %i[update destroy]

    def create
      @price_tier = @plan.price_tiers.build(price_tier_params)
      if @price_tier.save
        ControlPlane::Audit.log(action: "plan_price_tier.created", platform_admin: current_platform_admin,
          target: @price_tier, metadata: price_tier_params.to_h.merge(plan_id: @plan.id),
          ip_address: request.remote_ip)
        redirect_to control_plane_plan_path(@plan), notice: "Tier agregado."
      else
        redirect_to control_plane_plan_path(@plan), alert: @price_tier.errors.full_messages.to_sentence
      end
    end

    def update
      if @price_tier.update(price_tier_params)
        ControlPlane::Audit.log(action: "plan_price_tier.updated", platform_admin: current_platform_admin,
          target: @price_tier, metadata: price_tier_params.to_h, ip_address: request.remote_ip)
        redirect_to control_plane_plan_path(@plan), notice: "Tier actualizado."
      else
        redirect_to control_plane_plan_path(@plan), alert: @price_tier.errors.full_messages.to_sentence
      end
    end

    def destroy
      @price_tier.destroy!
      ControlPlane::Audit.log(action: "plan_price_tier.deleted", platform_admin: current_platform_admin,
        target: @plan, metadata: { deleted_tier_id: @price_tier.id }, ip_address: request.remote_ip)
      redirect_to control_plane_plan_path(@plan), notice: "Tier eliminado."
    end

    private

    def set_plan
      @plan = Plan.find(params[:plan_id])
    end

    def set_price_tier
      @price_tier = @plan.price_tiers.find(params[:id])
    end

    def price_tier_params
      params.require(:plan_price_tier).permit(:min_students, :max_students, :price_per_student_cents)
    end
  end
end
