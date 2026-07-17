# frozen_string_literal: true

module ControlPlane
  # Screen 2 — Institutions: list + detail + provisioning (v1.29.0, MVP item
  # #10 — new/create only, no edit/destroy: an institution's identity fields
  # don't change once it exists, and there's no product need to un-provision
  # one yet). The detail is the hub for subscription + entitlements (S2a),
  # headcount + usage rollups (S3a, read-only — those enter via push/
  # ingestion/job, never a form here), and invoices (S4 — generate/finalize/
  # void/re-cut, all under ControlPlane::InvoicesController).
  # `institution_id` is a global FK here, never an RLS scope.
  #
  # #create delegates ALL business logic to Provisioning::ProvisionInstitution
  # (lib/provisioning/) — this controller only translates form params <->
  # that one call + the platform audit log; no association was added to
  # Core::Institution for this.
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

      @invoices = Invoice.for_institution(@institution).most_recent_first.limit(10)
    end

    def new
      authorize_platform!("institutions.manage")
      @institution = Core::Institution.new(kind: "school")
    end

    def create
      authorize_platform!("institutions.manage")
      @institution = Core::Institution.new(institution_params)
      @admin_email = params[:institution][:admin_email].to_s.strip
      @admin_name = params[:institution][:admin_name].to_s.strip

      if @admin_email.blank? || @admin_name.blank?
        @institution.errors.add(:base, "El nombre y el correo del primer administrador son obligatorios.")
        return render :new, status: :unprocessable_entity
      end

      result = ::Provisioning::ProvisionInstitution.call(
        name: @institution.name, slug: @institution.slug, code: @institution.code, kind: @institution.kind,
        admin_email: @admin_email, admin_name: @admin_name
      )
      ControlPlane::Audit.log(action: "institution.provisioned", platform_admin: current_platform_admin,
        target: result.institution, metadata: { admin_email: result.admin_user.email }, ip_address: request.remote_ip)
      redirect_to control_plane_institution_path(result.institution),
        notice: "Institución creada. Invitamos a #{result.admin_user.email} como administrador."
    rescue ActiveRecord::RecordInvalid => e
      @institution.errors.add(:base, e.record.errors.full_messages.to_sentence)
      render :new, status: :unprocessable_entity
    end

    private

    def institution_params
      params.require(:institution).permit(:name, :slug, :code, :kind)
    end
  end
end
