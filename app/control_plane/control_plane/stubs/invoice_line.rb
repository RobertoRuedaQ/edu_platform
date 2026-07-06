# frozen_string_literal: true

module ControlPlane
  module Stubs
    # One typed line of a platform invoice. `kind` is the whole point: the three
    # hybrid-billing pieces are orthogonal and must render distinctly.
    #
    #   base_seats    — per-student base (quantity = students)
    #   addon_fee     — flat monthly fee per enabled addon
    #   usage_overage — events beyond quota (quantity = events, NEVER students)
    #
    # TODO: reemplazar por modelo real (ControlPlane::InvoiceLine).
    InvoiceLine = Data.define(
      :kind,
      :description,
      :quantity,
      :unit,          # "alumnos" | "mes" | event unit — labels the quantity
      :unit_price,
      :amount,
      :currency
    ) do
      KINDS = %w[base_seats addon_fee usage_overage].freeze

      def base_seats? = kind.to_s == "base_seats"
      def addon_fee? = kind.to_s == "addon_fee"
      def usage_overage? = kind.to_s == "usage_overage"
    end
  end
end
