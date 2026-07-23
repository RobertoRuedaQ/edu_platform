# frozen_string_literal: true

module ControlPlane
  # Records a manual payment against an invoice — nested under
  # institutions/:institution_id/invoices/:invoice_id, no index/show of its
  # own: payments are read inline on invoices#show (molde "una computación,
  # N superficies"). Same permission as finalize/void — no confidentiality
  # split that would justify a new one.
  class PaymentsController < BaseController
    before_action :set_institution
    before_action :set_invoice

    def create
      authorize_platform!("billing.manage")
      Billing::PaymentRecorder.call(invoice: @invoice, amount_cents: amount_cents, method: params[:method],
        paid_on: Date.parse(params[:paid_on]), notes: params[:notes].presence,
        recorded_by: current_platform_admin, idempotency_key: params[:idempotency_key])
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), notice: "Pago registrado."
    rescue ActiveRecord::RecordInvalid, Date::Error => e
      redirect_to control_plane_institution_invoice_path(@institution, @invoice), alert: e.message
    end

    private

    def amount_cents
      (BigDecimal(params[:amount].presence || "0") * 100).to_i
    end

    def set_institution
      @institution = Core::Institution.find(params[:institution_id])
    end

    def set_invoice
      @invoice = Invoice.where(institution_id: @institution.id).find(params[:invoice_id])
    end
  end
end
