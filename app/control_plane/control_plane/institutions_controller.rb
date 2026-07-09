# frozen_string_literal: true

module ControlPlane
  # Screen 2 — Institutions: list + detail, READ-ONLY (no new/create/edit/
  # destroy — provisioning an institution is out of scope). The detail is the
  # hub for subscription + entitlements (S2a) and now headcount + usage
  # rollups (S3a, also read-only — those enter via push/ingestion/job, never
  # a form here). `institution_id` is a global FK here, never an RLS scope.
  #
  # Does NOT touch app/domains/* beyond reading Core::Institution — no
  # association was added there; every query here goes through
  # ControlPlane::Subscription/Entitlement/StudentHeadcountSnapshot/
  # UsageDailyRollup directly.
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

      @headcount_snapshots = StudentHeadcountSnapshot.for_institution(@institution).most_recent_first.limit(10)
      @usage_rollups = UsageDailyRollup.for_institution(@institution).includes(:addon)
        .most_recent_first.limit(20)
    end
  end
end
