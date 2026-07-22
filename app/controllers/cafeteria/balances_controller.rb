module Cafeteria
  # Reuses finance.read (treasury already owns "cartera y pagos") rather than
  # a new balance.view — cafeteria prepaid balances are the same specialty.
  class BalancesController < ApplicationController
    def index
      authorize!("finance.read")
      @accounts = Cafeteria::AccountScope.new(context: authorization_context).resolve
    end
  end
end
