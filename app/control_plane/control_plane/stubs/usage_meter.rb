# frozen_string_literal: true

module ControlPlane
  module Stubs
    # Metered consumption of one addon against its included quota, for one
    # institution and period. Overage counts EVENTS, never students.
    #
    # `threshold` is the alert mark (e.g. 80% of quota) the meter renders.
    #
    # TODO: reemplazar por medición real (agregado de eventos, no ActiveRecord
    #       fila-a-fila).
    UsageMeter = Data.define(
      :label,               # what is being metered (es)
      :addon_name,
      :unit,                # event unit (e.g. "transacciones")
      :used,                # events consumed this period
      :quota,               # included allowance; nil = unlimited
      :threshold,           # alert mark in event units; nil = none
      :currency,
      :overage_unit_price   # price per event beyond quota
    ) do
      def unlimited? = quota.nil?
      def over_quota? = !unlimited? && used > quota
      def overage = over_quota? ? used - quota : 0
      def at_threshold? = threshold.present? && used >= threshold

      # Clamped 0..100 for the bar width; nil when unlimited (no denominator).
      def percent
        return nil if unlimited? || quota.to_i.zero?

        [ (used.to_f / quota * 100).round, 100 ].min
      end

      def overage_cost
        return 0 unless over_quota? && overage_unit_price

        overage * overage_unit_price
      end
    end
  end
end
