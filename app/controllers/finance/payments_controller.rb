module Finance
  # Records an offline payment against an account. The real target model
  # (Finance::Payment) already existed before this slice — so the write is
  # cabled completely, not gate-only. #new stamps a fresh idempotency_key
  # into a hidden field; #create carries it back so a double-submit of the
  # SAME form returns the already-recorded payment (Finance::PaymentRecorder)
  # instead of recording a second one.
  class PaymentsController < ApplicationController
    def new
      @account = find_account
      authorize!("finance.write", @account)
      @idempotency_key = SecureRandom.uuid
      @pending_charges = Finance::Charge.where(institution_id: Current.institution_id,
        student_id: @account.student_id, status: %w[pending overdue]).order(:due_on)
    end

    def create
      @account = find_account
      authorize!("finance.write", @account)

      charge = if params[:charge_id].present?
        Finance::Charge.find_by(institution_id: Current.institution_id, student_id: @account.student_id,
          id: params[:charge_id])
      end
      amount = BigDecimal(params[:amount].presence || "0")

      if amount <= 0
        @error = "El monto debe ser mayor a cero."
        @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
        @pending_charges = Finance::Charge.where(institution_id: Current.institution_id,
          student_id: @account.student_id, status: %w[pending overdue]).order(:due_on)
        return render :new, status: :unprocessable_entity
      end

      Finance::PaymentRecorder.call(institution: Current.institution, account: @account, amount: amount,
        method: params[:method], charge: charge, idempotency_key: params[:idempotency_key])

      redirect_to finance_account_path(@account), notice: "Pago registrado."
    end

    private

    def find_account
      account = Finance::StudentAccount.find_by(institution_id: Current.institution_id, id: params[:account_id])
      raise ActiveRecord::RecordNotFound if account.nil?

      account
    end
  end
end
