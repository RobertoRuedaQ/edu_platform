module ControlPlane
  module Billing
    # Thin Solid Queue wrapper over PeriodCut. Deliberately does NOT set
    # institution_id on itself (the ApplicationJob attr_accessor) — invoices/
    # invoice_line_items are GLOBAL tables, so this must run with NO GUC
    # fixed, same posture as ControlPlane::Usage::RollupJob. Invocable
    # manually/rake; recurring schedule deferred.
    class PeriodCutJob < ApplicationJob
      def perform(institution_id:, period_start:, period_end:)
        institution = Core::Institution.find(institution_id)
        PeriodCut.call(institution: institution, period_start: period_start, period_end: period_end)
      end
    end
  end
end
