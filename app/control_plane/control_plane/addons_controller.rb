# frozen_string_literal: true

module ControlPlane
  # Screen 3 — Addon catalog: real CRUD (soft-retire, never destroy). Any
  # authenticated platform_admin may manage the catalog — no intra-plane RBAC
  # in S1 (scope creep, deferred).
  class AddonsController < BaseController
    before_action :set_addon, only: %i[show edit update retire reactivate]

    def index
      @addons = Addon.order(:key)
    end

    def show
    end

    def new
      @addon = Addon.new(metered: false, currency: "COP")
    end

    def create
      @addon = Addon.new(addon_params)
      if @addon.save
        ControlPlane::Audit.log(action: "addon.created", platform_admin: current_platform_admin,
          target: @addon, metadata: addon_params.to_h, ip_address: request.remote_ip)
        redirect_to control_plane_addon_path(@addon), notice: "Addon creado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      before = @addon.attributes.slice(*addon_params.keys)
      if @addon.update(addon_params)
        ControlPlane::Audit.log(action: "addon.updated", platform_admin: current_platform_admin,
          target: @addon, metadata: { before: before, after: addon_params.to_h }, ip_address: request.remote_ip)
        redirect_to control_plane_addon_path(@addon), notice: "Addon actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def retire
      @addon.retire!
      ControlPlane::Audit.log(action: "addon.retired", platform_admin: current_platform_admin,
        target: @addon, ip_address: request.remote_ip)
      redirect_to control_plane_addons_path, notice: "Addon retirado."
    end

    def reactivate
      @addon.reactivate!
      ControlPlane::Audit.log(action: "addon.reactivated", platform_admin: current_platform_admin,
        target: @addon, ip_address: request.remote_ip)
      redirect_to control_plane_addons_path, notice: "Addon reactivado."
    end

    private

    def set_addon
      @addon = Addon.find(params[:id])
    end

    def addon_params
      params.require(:addon).permit(
        :key, :name, :description, :monthly_fee_cents, :currency,
        :metered, :included_quota, :unit, :overage_unit_price_cents
      )
    end
  end
end
