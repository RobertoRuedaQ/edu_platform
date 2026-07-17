# frozen_string_literal: true

module ControlPlane
  # Screen 3 — Addon catalog: real CRUD (soft-retire, never destroy). Reads
  # (index/show) stay open to any active platform_admin; mutations require
  # catalog.manage (RBAC intra-plano, v1.31.0 — see ControlPlane::Authorization).
  class AddonsController < BaseController
    before_action :set_addon, only: %i[show edit update retire reactivate]

    def index
      @addons = Addon.order(:key)
    end

    def show
    end

    def new
      authorize_platform!("catalog.manage")
      @addon = Addon.new(metered: false, currency: "COP")
    end

    def create
      authorize_platform!("catalog.manage")
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
      authorize_platform!("catalog.manage")
    end

    def update
      authorize_platform!("catalog.manage")
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
      authorize_platform!("catalog.manage")
      dependent = @addon.entitlements.active.includes(:institution)
      if dependent.exists?
        names = dependent.map { |e| e.institution.name }.uniq.join(", ")
        return redirect_to control_plane_addons_path,
          alert: "No se puede retirar: instituciones con entitlement activo (#{names})."
      end

      @addon.retire!
      ControlPlane::Audit.log(action: "addon.retired", platform_admin: current_platform_admin,
        target: @addon, ip_address: request.remote_ip)
      redirect_to control_plane_addons_path, notice: "Addon retirado."
    end

    def reactivate
      authorize_platform!("catalog.manage")
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
