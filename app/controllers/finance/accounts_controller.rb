module Finance
  # Index + show — molde #4 (§6.6), same shape as the other supervision
  # surfaces. Reuses the ALREADY-existing finance.read/finance.write
  # permissions (seeded since before this slice, and already consumed by
  # Cafeteria::BalancesController for its own "Saldos" feature) rather than
  # inventing new keys — see HISTORIA.md v1.18.0.
  class AccountsController < ApplicationController
    def index
      authorize!("finance.read")
      @accounts = Finance::AccountScope.new(context: authorization_context).resolve
    end

    def show
      @account = find_account
      authorize!("finance.read", @account)
      @statement = Finance::AccountStatement.call(@account)
    end

    private

    def find_account
      account = Finance::StudentAccount.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if account.nil?

      account
    end
  end
end
