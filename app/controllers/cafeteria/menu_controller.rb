module Cafeteria
  # No Query object here: a menu has no group/department dimension to scope by
  # — it's the same menu for the whole institution. authorize! alone is the
  # correct gate (nothing to filter per row).
  class MenuController < ApplicationController
    def index
      authorize!("menu.view")
      @items = Cafeteria::MenuItem.where(institution_id: Current.institution_id).available.order(:category, :name)
    end
  end
end
