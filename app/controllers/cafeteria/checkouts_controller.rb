module Cafeteria
  # The allergen block is REAL logic enforced against REAL student data
  # (guidelines/CLOSURE_PLAN.md Fase D — Cafeteria::DietaryRestriction was
  # already a real, seeded table; only this controller still read a parallel
  # stub). new computes it to show cashier_staff which lines are blocked (via
  # cafeteria/_checkout_line, which only ever reflects the flag it's given);
  # create RE-checks server-side and refuses to complete the sale if any
  # selected item is blocked, even if the client somehow submitted it anyway.
  #
  # The sale itself is real too now (cafeteria resto, second half of Fase D's
  # cafeteria increment): create delegates to Cafeteria::PurchaseRecorder
  # (Menu/Purchase/Finance::Charge, account.lock! transactional) instead of
  # the old stub flash-only path.
  class CheckoutsController < ApplicationController
    def new
      authorize!("checkout.manage")
      @student = find_student
      @items = menu_items
      @idempotency_key = SecureRandom.uuid
    end

    def create
      authorize!("checkout.manage")
      @student = find_student or raise ActiveRecord::RecordNotFound
      @items = menu_items
      selected = @items.select { |item| Array(params[:item_ids]).include?(item.id.to_s) }
      blocked = selected.select { |item| blocked_for_student?(item) }

      if blocked.any?
        flash.now[:alert] = "Compra bloqueada: #{blocked.map(&:name).join(', ')} " \
                             "contraindica el registro médico de #{student_name}."
        @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
        render :new, status: :unprocessable_entity
        return
      end

      if selected.empty?
        flash.now[:alert] = "Selecciona al menos un producto."
        @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
        render :new, status: :unprocessable_entity
        return
      end

      Cafeteria::PurchaseRecorder.call(
        institution: Current.institution, student: @student, menu_items: selected,
        recorded_by: Current.institution_user, idempotency_key: params[:idempotency_key]
      )
      flash[:notice] = "Compra registrada para #{student_name}."
      redirect_to cafeteria_menu_path
    end

    private

    def menu_items
      Cafeteria::MenuItem.where(institution_id: Current.institution_id).available.order(:category, :name)
    end

    # The search form takes a student_code (cashier types it in, "Ej.
    # COL-E-101"); the hidden field on the confirm step re-submits the
    # already-resolved real id instead — this accepts either.
    def find_student
      return nil if params[:student_id].blank?

      GroupManagement::Student.find_by(institution_id: Current.institution_id, student_code: params[:student_id]) ||
        GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
    end

    def student_name
      "#{@student.first_name} #{@student.last_name}"
    end

    def blocked_for_student?(item)
      allergen_names = Cafeteria::DietaryRestriction
        .where(institution_id: Current.institution_id, student_id: @student.id)
        .blocking.map(&:allergen_name)
      item.allergens.any? { |allergen| allergen_names.include?(allergen) }
    end
  end
end
