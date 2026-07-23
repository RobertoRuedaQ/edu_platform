# frozen_string_literal: true

module ControlPlane
  # Screen 7 — Billing: invoices + line items in three sections
  # (base_seats / addon_fee / usage_overage). Platform billing the SCHOOL —
  # NOT the finance domain.
  #
  # `index` (real as of S4) is a flat, cross-institution overview — reachable
  # from the main nav without picking an institution first. The per-
  # institution workflow (generate a draft, finalize, void, re-cut) lives
  # nested under institutions/:institution_id/invoices — same shape as
  # subscriptions (S2a). A draft is regenerable; finalized/void are not.
  class InvoicesController < BaseController
    before_action :set_institution, only: %i[new create show finalize void recut]
    before_action :set_invoice, only: %i[show finalize void recut]

    def index
      @invoices = Invoice.includes(:institution, :billing_period).most_recent_first.limit(200)
    end

    def new
      authorize_platform!("billing.manage")
      @invoice = Invoice.new
      @period_start = Date.current.beginning_of_month
      @period_end = Date.current.end_of_month
    end

    def create
      authorize_platform!("billing.manage")
      billing_period = BillingPeriod.find_or_create_by!(institution: @institution,
        starts_on: Date.parse(invoice_params[:period_start]), ends_on: Date.parse(invoice_params[:period_end]))
      @invoice = Billing::PeriodCut.call(institution: @institution, billing_period: billing_period)
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), notice: "Borrador generado."
    rescue Billing::PeriodCut::NoActiveSubscription, Billing::PeriodCut::AlreadyFinalized, Date::Error,
           ActiveRecord::RecordInvalid => e
      @invoice = Invoice.new
      @period_start = invoice_params[:period_start]
      @period_end = invoice_params[:period_end]
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def show
    end

    def finalize
      authorize_platform!("billing.manage")
      @invoice.finalize!
      ControlPlane::Audit.log(action: "invoice.finalized", platform_admin: current_platform_admin,
        target: @invoice, ip_address: request.remote_ip)
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), notice: "Factura finalizada."
    rescue Invoice::InvalidTransition => e
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), alert: e.message
    end

    def void
      authorize_platform!("billing.manage")
      @invoice.void!
      ControlPlane::Audit.log(action: "invoice.voided", platform_admin: current_platform_admin,
        target: @invoice, ip_address: request.remote_ip)
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), notice: "Factura anulada."
    rescue Invoice::InvalidTransition => e
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), alert: e.message
    end

    def recut
      authorize_platform!("billing.manage")
      Billing::PeriodCut.call(institution: @institution, billing_period: @invoice.billing_period)
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), notice: "Borrador recortado de nuevo."
    rescue Billing::PeriodCut::AlreadyFinalized => e
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), alert: e.message
    end

    private

    def set_institution
      @institution = Core::Institution.find(params[:institution_id])
    end

    def set_invoice
      @invoice = Invoice.where(institution_id: @institution.id).find(params[:id])
    end

    def invoice_params
      params.require(:invoice).permit(:period_start, :period_end)
    end
  end
end
