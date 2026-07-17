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

          PeriodCutJob.perform_later(institution_id: institution.id,
            period_start: period_start, period_end: period_end)
        end
      end
    end
  end
end
