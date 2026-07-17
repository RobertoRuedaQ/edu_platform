# frozen_string_literal: true

module ControlPlane
  # Screen 5 — Plans & pricing: per-student base rate + volume brackets. Addon
  # fees/overage are catalogued separately (Addon) — F9, no FK between them.
  # Reads open to any active platform_admin; mutations require catalog.manage
  # (RBAC intra-plano, v1.31.0 — see ControlPlane::Authorization).
  class PlansController < BaseController
    before_action :set_plan, only: %i[show edit update retire reactivate]

    def index
      @plans = Plan.order(:key).includes(:price_tiers)
    end

    def show
    end

    def new
      authorize_platform!("catalog.manage")
      @plan = Plan.new(currency: "COP")
    end

    def create
      authorize_platform!("catalog.manage")
      @plan = Plan.new(plan_params)
      if @plan.save
        ControlPlane::Audit.log(action: "plan.created", platform_admin: current_platform_admin,
          target: @plan, metadata: plan_params.to_h, ip_address: request.remote_ip)
        redirect_to control_plane_plan_path(@plan), notice: "Plan creado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_platform!("catalog.manage")
    end

    def update
      authorize_platform!("catalog.manage")
      before = @plan.attributes.slice(*plan_params.keys)
      if @plan.update(plan_params)
        ControlPlane::Audit.log(action: "plan.updated", platform_admin: current_platform_admin,
          target: @plan, metadata: { before: before, after: plan_params.to_h }, ip_address: request.remote_ip)
        redirect_to control_plane_plan_path(@plan), notice: "Plan actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def retire
      authorize_platform!("catalog.manage")
      @plan.retire!
      ControlPlane::Audit.log(action: "plan.retired", platform_admin: current_platform_admin,
        target: @plan, ip_address: request.remote_ip)
      redirect_to control_plane_plans_path, notice: "Plan retirado."
    end

    def reactivate
      authorize_platform!("catalog.manage")
      @plan.reactivate!
      ControlPlane::Audit.log(action: "plan.reactivated", platform_admin: current_platform_admin,
        target: @plan, ip_address: request.remote_ip)
      redirect_to control_plane_plans_path, notice: "Plan reactivado."
    end

    private

    def set_plan
      @plan = Plan.find(params[:id])
    end

    def plan_params
      params.require(:plan).permit(:key, :name, :description, :base_price_per_student_cents, :currency)
    end
  end
end
