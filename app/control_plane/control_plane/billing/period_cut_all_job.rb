module ControlPlane
  module Billing
    # Recurring fan-out (v1.32.0) — the entry config/recurring.yml points at.
    # Cuts the PREVIOUS full calendar month for every institution that has an
    # active subscription right now; institutions without one are skipped
    # (never enqueued) rather than letting PeriodCutJob raise
    # NoActiveSubscription for each — that rejection is the expected common
    # case here (most institutions won't have billing active every month),
    # not a failure worth logging as one.
    class PeriodCutAllJob < ApplicationJob
      def perform(as_of: Date.current)
        period_start = as_of.prev_month.beginning_of_month
        period_end = as_of.prev_month.end_of_month

        Core::Institution.find_each do |institution|
          next unless ControlPlane::Subscription.active.exists?(institution_id: institution.id)

          billing_period = ControlPlane::BillingPeriod.find_or_create_by!(institution: institution,
            starts_on: period_start, ends_on: period_end)
          PeriodCutJob.perform_later(institution_id: institution.id, billing_period_id: billing_period.id)
        end
      end
    end
  end
end
