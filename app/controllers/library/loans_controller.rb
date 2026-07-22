module Library
  class LoansController < ApplicationController
    def index
      authorize!("library.loans.manage")
      @loans = Library::LoanScope.new(context: authorization_context).resolve
    end
  end
end
