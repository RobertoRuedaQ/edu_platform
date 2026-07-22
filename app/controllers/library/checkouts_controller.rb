module Library
  # One-step desk: this page also posts to Returns#create (library_prompt.md
  # "interfaz de salida/entrada de libros en un solo paso") — #new renders
  # both forms, #create only ever handles LENDING.
  #
  # Borrower lookup accepts EITHER a student_code (the spec's own explicit
  # UX: "documento del estudiante") or a staff member's email — the schema
  # supports both borrower types (see Library::Loan's borrower XOR), the
  # desk UI just needs one identifier field that tries both.
  class CheckoutsController < ApplicationController
    def new
      authorize!("library.checkout")
      @idempotency_key = SecureRandom.uuid
    end

    def create
      authorize!("library.checkout")
      copy = find_copy
      borrower = find_borrower

      if copy.nil?
        flash.now[:alert] = "No se encontró un ejemplar con ese código de barras."
        return render_new_with_error
      end

      if borrower.nil?
        flash.now[:alert] = "No se encontró un prestatario con ese código o correo."
        return render_new_with_error
      end

      Library::LoanRecorder.call(
        institution: Current.institution, copy: copy, borrower: borrower,
        issued_by: Current.institution_user, idempotency_key: params[:idempotency_key]
      )
      redirect_to library_checkouts_path, notice: "Préstamo registrado."
    rescue Library::LoanRecorder::NotAvailable
      flash.now[:alert] = "El ejemplar no está disponible."
      render_new_with_error
    rescue Library::LoanRecorder::BorrowLimitExceeded
      flash.now[:alert] = "El prestatario ya alcanzó su máximo de préstamos activos."
      render_new_with_error
    end

    private

    def render_new_with_error
      @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
      render :new, status: :unprocessable_entity
    end

    def find_copy
      return nil if params[:barcode].blank?

      Library::ResourceCopy.find_by(institution_id: Current.institution_id, barcode: params[:barcode])
    end

    def find_borrower
      identifier = params[:borrower_identifier]
      return nil if identifier.blank?

      GroupManagement::Student.find_by(institution_id: Current.institution_id, student_code: identifier) ||
        staff_borrower_by_email(identifier)
    end

    def staff_borrower_by_email(email)
      user = Core::User.find_by(email: email)
      return nil unless user

      Core::InstitutionUser.find_by(institution_id: Current.institution_id, user_id: user.id)
    end
  end
end
