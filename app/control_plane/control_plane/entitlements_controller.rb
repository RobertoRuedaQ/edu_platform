# frozen_string_literal: true

module ControlPlane
  # Screen 4 — entitlement editor for one institution. Gate #1 of two serial
  # gates (entitlement, then RBAC in identity_access — S2b, out of scope).
  #
  # Real CRUD as of S2a (was index-only, toggle-visual-only stub before).
  # index/new/create read the institution from ?institution_id=; edit/update/
  # revoke/reactivate operate on the entitlement directly (its institution_id
  # is already fixed).
  class EntitlementsController < BaseController
    before_action :set_institution, only: %i[index new create]
    before_action :set_entitlement, only: %i[edit update revoke reactivate]

    def index
      @institution = Core::Institution.find(params[:institution_id]) if params[:institution_id]
      return redirect_to control_plane_institutions_path, alert: "Selecciona una institución primero." unless @institution

      @entitlements = Entitlement.where(institution_id: @institution.id).includes(:addon).order(:created_at)
      @grantable_addons = Addon.active.where.not(
        id: Entitlement.where(institution_id: @institution.id).select(:addon_id)
      )
    end

    def new
      authorize_platform!("billing.manage")
      @entitlement = Entitlement.new(institution_id: @institution.id, valid_from: Date.current)
      @grantable_addons = Addon.active.where.not(
        id: Entitlement.where(institution_id: @institution.id).select(:addon_id)
      )
    end

    def create
      authorize_platform!("billing.manage")
      @entitlement = Entitlement.new(entitlement_params.merge(institution_id: @institution.id))
      if @entitlement.save
        ControlPlane::Audit.log(action: "entitlement.granted", platform_admin: current_platform_admin,
          target: @entitlement, metadata: entitlement_params.to_h.merge(institution_id: @institution.id),
          ip_address: request.remote_ip)
        redirect_to control_plane_entitlements_path(institution_id: @institution.id), notice: "Addon concedido."
      else
        @grantable_addons = Addon.active.where.not(
          id: Entitlement.where(institution_id: @institution.id).select(:addon_id)
        )
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_platform!("billing.manage")
    end

    def update
      authorize_platform!("billing.manage")
      before = @entitlement.attributes.slice(*entitlement_params.keys)
      if @entitlement.update(entitlement_params)
        ControlPlane::Audit.log(action: "entitlement.updated", platform_admin: current_platform_admin,
          target: @entitlement, metadata: { before: before, after: entitlement_params.to_h },
          ip_address: request.remote_ip)
        redirect_to control_plane_entitlements_path(institution_id: @entitlement.institution_id),
          notice: "Entitlement actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def revoke
      authorize_platform!("billing.manage")
      @entitlement.revoke!
      ControlPlane::Audit.log(action: "entitlement.revoked", platform_admin: current_platform_admin,
        target: @entitlement, ip_address: request.remote_ip)
      redirect_to control_plane_entitlements_path(institution_id: @entitlement.institution_id),
        notice: "Entitlement revocado."
    rescue ActiveRecord::RecordInvalid
      redirect_to control_plane_entitlements_path(institution_id: @entitlement.institution_id),
        alert: "No se puede revocar un entitlement el mismo día en que se otorgó — espera al día siguiente."
    end

    def reactivate
      authorize_platform!("billing.manage")
      conflicting = Entitlement.active.where(institution_id: @entitlement.institution_id, addon_id: @entitlement.addon_id)
        .where.not(id: @entitlement.id)
      if conflicting.exists?
        return redirect_to control_plane_entitlements_path(institution_id: @entitlement.institution_id),
          alert: "Ya hay un entitlement activo de este addon para esta institución."
      end

      @entitlement.reactivate!
      ControlPlane::Audit.log(action: "entitlement.reactivated", platform_admin: current_platform_admin,
        target: @entitlement, ip_address: request.remote_ip)
      redirect_to control_plane_entitlements_path(institution_id: @entitlement.institution_id),
        notice: "Entitlement reactivado."
    end

    private

    def set_institution
      @institution = Core::Institution.find(params[:institution_id])
    end

    def set_entitlement
      @entitlement = Entitlement.find(params[:id])
    end

    def entitlement_params
      params.require(:entitlement).permit(
        :addon_id, :valid_from, :valid_until,
        :override_monthly_fee_cents, :override_included_quota,
        :override_unit_price_cents, :override_currency
      )
    end
  end
end
