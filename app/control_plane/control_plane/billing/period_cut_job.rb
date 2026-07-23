module ControlPlane
  module Billing
    # Thin Solid Queue wrapper over PeriodCut. Deliberately does NOT set
    # institution_id on itself (the ApplicationJob attr_accessor) — invoices/
    # invoice_line_items are GLOBAL tables, so this must run with NO GUC
    # fixed, same posture as ControlPlane::Usage::RollupJob. Invocable
    # manually/rake, AND (v1.32.0) enqueued monthly per institution by
    # ControlPlane::Billing::PeriodCutAllJob (config/recurring.yml).
    class PeriodCutJob < ApplicationJob
      def perform(institution_id:, billing_period_id:)
        institution = Core::Institution.find(institution_id)
        billing_period = ControlPlane::BillingPeriod.find(billing_period_id)
        PeriodCut.call(institution: institution, billing_period: billing_period)
      end
    end
  end
end
