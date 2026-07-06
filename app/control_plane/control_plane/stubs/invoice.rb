# frozen_string_literal: true

module ControlPlane
  module Stubs
    # A platform invoice: the PLATFORM charging the SCHOOL. This is NOT the
    # finance domain (that is the school charging guardians, under RLS). Do not
    # mix the two.
    #
    # TODO: reemplazar por modelo real (ControlPlane::Invoice + InvoiceLine).
    Invoice = Data.define(
      :number,
      :institution_name,
      :period_label,      # e.g. "Julio 2026"
      :status,            # "draft" | "open" | "paid" | "past_due"
      :currency,
      :lines              # [InvoiceLine]
    ) do
      def subtotal = lines.sum(&:amount)

      # Lines grouped into the three billing sections, in a fixed display order.
      def lines_of(kind) = lines.select { |line| line.kind.to_s == kind.to_s }
    end
  end
end
