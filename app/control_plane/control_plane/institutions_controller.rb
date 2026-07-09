# frozen_string_literal: true

module ControlPlane
  # Screen 2 — Institutions: list + detail, READ-ONLY (no new/create/edit/
  # destroy — provisioning an institution is out of S2a's scope). The detail
  # is the hub for subscription + entitlements. `institution_id` is a global
  # FK here, never an RLS scope.
  #
  # Real as of S2a. Does NOT touch app/domains/* beyond reading
  # Core::Institution — no association was added there; every query here
  # goes through ControlPlane::Subscription/Entitlement directly.
  class InstitutionsController < BaseController
    def index
      @institutions = Core::Institution.order(:name)
      @active_subscriptions = Subscription.active
        .where(institution_id: @institutions.select(:id)).index_by(&:institution_id)
    end

    def show
      @institution = Core::Institution.find(params[:id])
      @active_subscription = Subscription.active.find_by(institution_id: @institution.id)
      @subscription_history = Subscription.where(institution_id: @institution.id).ended.order(signed_at: :desc)
      @entitlements = Entitlement.where(institution_id: @institution.id).includes(:addon).order(:created_at)
      @grantable_addons = Addon.active.where.not(
        id: Entitlement.where(institution_id: @institution.id).select(:addon_id)
      )
    end
  end
end
