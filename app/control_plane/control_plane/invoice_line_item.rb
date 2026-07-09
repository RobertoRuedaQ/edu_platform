module ControlPlane
  # GLOBAL — one typed line of a draft invoice (§7.3's hybrid model: base_seats
  # + addon_fee + usage_overage). Frozen at cut time — amount_cents is
  # `quantity * unit_price_cents`, computed once and never recomputed live.
  # Append-only once persisted (`readonly? = persisted?`): PeriodCut's
  # idempotent re-cut of a DRAFT deletes and recreates lines, it never edits
  # one in place.
  class InvoiceLineItem < ApplicationRecord
    self.table_name = "invoice_line_items"

    KINDS = %w[base_seats addon_fee usage_overage].freeze

    belongs_to :invoice, class_name: "ControlPlane::Invoice"
    belongs_to :addon, class_name: "ControlPlane::Addon", optional: true

    validates :kind, inclusion: { in: KINDS }
    validates :description, presence: true
    validates :quantity, numericality: { greater_than_or_equal_to: 0 }
    validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
    validates :amount_cents, presence: true
    validate :addon_presence_matches_kind

    def base_seats? = kind == "base_seats"
    def addon_fee? = kind == "addon_fee"
    def usage_overage? = kind == "usage_overage"

    # Decimal helpers for the existing shared/_invoice_line partial (same
    # convention as Addon#monthly_fee / Plan#base_price_per_student — cents
    # only ever become a display decimal here, at the view boundary).
    def unit_price = unit_price_cents / 100.0
    def amount = amount_cents / 100.0

    def readonly?
      persisted?
    end

    private

    def addon_presence_matches_kind
      if base_seats? && addon_id.present?
        errors.add(:addon_id, "debe estar vacío para una línea base_seats")
      elsif !base_seats? && addon_id.nil?
        errors.add(:addon_id, "es requerido para una línea #{kind}")
      end
    end
  end
end
