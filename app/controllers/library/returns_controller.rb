module Library
  # Second half of the one-step desk (see CheckoutsController) — posts from
  # the same page, by barcode only (the active loan is resolved from the
  # copy, never trusted from a client-supplied loan id).
  class ReturnsController < ApplicationController
    def create
      authorize!("library.checkout")
      loan = find_active_loan

      if loan.nil?
        redirect_to new_library_checkout_path, alert: "No hay un préstamo activo para ese código de barras."
        return
      end

      Library::ReturnRecorder.call(institution: Current.institution, loan: loan)
      redirect_to new_library_checkout_path, notice: "Devolución registrada."
    end

    private

    def find_active_loan
      copy = Library::ResourceCopy.find_by(institution_id: Current.institution_id, barcode: params[:barcode])
      return nil if copy.nil?

      copy.loans.active.first
    end
  end
end
