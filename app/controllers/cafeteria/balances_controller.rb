module Cafeteria
  # Reuses finance.read (treasury already owns "cartera y pagos") rather than
  # a new balance.view — cafeteria prepaid balances are the same specialty.
  # Institution-wide only, so no Query object: nothing to scope per row.
  class BalancesController < ApplicationController
    def index
      authorize!("finance.read")
      @accounts = Cafeteria::StudentAccountRoster.all
    end
  end
end
