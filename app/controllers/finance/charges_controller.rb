module Finance
  # Creates a charge against an account. Same idempotency-key-in-hidden-field
  # discipline as PaymentsController — see Finance::ChargeCreator.
  class ChargesController < ApplicationController
    def new
      @account = find_account
      authorize!("finance.write", @account)
      @idempotency_key = SecureRandom.uuid
    end

    def create
      @account = find_account
      authorize!("finance.write", @account)

      amount = BigDecimal(params[:amount].presence || "0")
      due_on = parse_date(params[:due_on])

      if amount <= 0
        @error = "El monto debe ser mayor a cero."
        @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
        return render :new, status: :unprocessable_entity
      end

      Finance::ChargeCreator.call(institution: Current.institution, account: @account, amount: amount,
        description: params[:description], due_on: due_on, idempotency_key: params[:idempotency_key])

      redirect_to finance_account_path(@account), notice: "Cargo creado."
    end

    private

    def find_account
      account = Finance::StudentAccount.find_by(institution_id: Current.institution_id, id: params[:account_id])
      raise ActiveRecord::RecordNotFound if account.nil?

      account
    end

    def parse_date(value)
      Date.iso8601(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
