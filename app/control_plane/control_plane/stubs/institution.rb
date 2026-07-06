# frozen_string_literal: true

module ControlPlane
  module Stubs
    # A tenant institution AS SEEN FROM THE CONTROL PLANE (cross-tenant, above
    # RLS). Here `id` is a GLOBAL FK, never an RLS scope key — no tenant scoping
    # applies to these screens.
    #
    # `next_invoice_estimate` is a stub number; the real one comes from the
    # hybrid billing calc (base_seats + addon_fee + usage_overage).
    #
    # TODO: reemplazar por modelo real (referencia global a Core::Institution
    #       + suscripción de plataforma).
    Institution = Data.define(
      :id,
      :name,
      :plan_name,
      :plan_key,
      :subscription_status,   # "active" | "trialing" | "past_due" | "canceled"
      :status,                # operational status: "active" | "suspended"
      :students_count,        # drives base_seats billing
      :mrr,
      :currency,
      :enabled_addon_names,    # [String] for the summary card
      :next_invoice_estimate
    ) do
      def active? = status.to_s == "active"
    end
  end
end
