module Cafeteria
  # The allergen block is REAL logic enforced against REAL student data
  # (guidelines/CLOSURE_PLAN.md Fase D — Cafeteria::DietaryRestriction was
  # already a real, seeded table; only this controller still read a parallel
  # stub). new computes it to show cashier_staff which lines are blocked (via
  # cafeteria/_checkout_line, which only ever reflects the flag it's given);
  # create RE-checks server-side and refuses to complete the sale if any
  # selected item is blocked, even if the client somehow submitted it anyway.
  #
  # Menu/Purchase are STILL stub (Cafeteria::MenuRoster, no real Menu/
  # MenuItem/Purchase model exists) — deliberately out of scope for this
  # increment. The safety-critical half (does this real student have a real
  # allergy that blocks this line) is what "habilita alérgenos" (§Fase D)
  # actually asked for; persisting a real sale is a separate, larger slice
  # (needs Menu/MenuItem + Purchase + StudentAccount balance deduction with
  # locking) left for its own future increment, driver-based.
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
                             "contraindica el registro médico de #{student_name}."
        render :new, status: :unprocessable_entity
        return
      end

      # STILL STUB: no Cafeteria::Purchase model exists yet — deferred, see
      # class comment. The allergen check above is real; the sale itself isn't.
      flash[:notice] = "Compra registrada (stub) para #{student_name}."
      redirect_to cafeteria_menu_path
    end

    private

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
      item.allergens.any? { |allergen| allergen_names.include?(allergen.name) }
    end
  end
end
