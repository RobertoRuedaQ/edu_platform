module Cafeteria
  # The allergen block is REAL logic, enforced here — not cosmetic. new
  # computes it to show cashier_staff which lines are blocked (via
  # cafeteria/_checkout_line, which only ever reflects the flag it's given);
  # create RE-checks server-side and refuses to complete the sale if any
  # selected item is blocked, even if the client somehow submitted it anyway.
  class CheckoutsController < ApplicationController
    def new
      authorize!("checkout.manage")
      @student = find_student
      @items = Cafeteria::MenuRoster.all
    end

    def create
      authorize!("checkout.manage")
      @student = find_student or raise ActiveRecord::RecordNotFound
      @items = Cafeteria::MenuRoster.all
      selected = @items.select { |item| Array(params[:item_ids]).include?(item.id) }
      blocked = selected.select { |item| blocked_for_student?(item) }

      if blocked.any?
        flash.now[:alert] = "Compra bloqueada: #{blocked.map(&:name).join(', ')} " \
                             "contraindica el registro médico de #{@student.name}."
        render :new, status: :unprocessable_entity
        return
      end

      # STUB: no persistence yet. TODO: reemplazar por Cafeteria::Purchase real.
      flash[:notice] = "Compra registrada (stub) para #{@student.name}."
      redirect_to cafeteria_menu_path
    end

    private

    def find_student
      return nil if params[:student_id].blank?

      GroupManagement::StudentRoster.find(params[:student_id])
    end

    def blocked_for_student?(item)
      allergen_names = Cafeteria::DietaryRestrictionRoster.blocking_allergen_names(@student.id)
      item.allergens.any? { |allergen| allergen_names.include?(allergen.name) }
    end
  end
end
