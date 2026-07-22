module Cafeteria
  # One item within a Purchase. `item_name`/`unit_price_cents` are frozen at
  # sale time (molde `lines_snapshot`/`framework_snapshot`) — a later edit to
  # the menu item's own name/price must never rewrite a past sale's history.
  class PurchaseLine < ApplicationRecord
    self.table_name = "cafeteria_purchase_lines"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :purchase, class_name: "Cafeteria::Purchase", inverse_of: :purchase_lines
    belongs_to :menu_item, class_name: "Cafeteria::MenuItem", inverse_of: :purchase_lines

    validates :item_name, presence: true
    validates :unit_price_cents, numericality: { greater_than: 0 }

    def unit_price_amount = BigDecimal(unit_price_cents) / 100
  end
end
