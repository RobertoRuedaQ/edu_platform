module ControlPlane
  module Usage
    # Aggregates usage_events into usage_daily_rollups for one usage_date.
    # Domain-agnostic, GLOBAL tables — no GUC (G6). Inherits ApplicationJob
    # for consistency with Core::Headcount::SnapshotJob, but never sets
    # institution_id, so ApplicationJob's around_perform takes its "no
    # tenant" branch and runs with no GUC set, on purpose.
    #
    # Idempotent (G4): always FULLY recomputes total_quantity/event_count from
    # usage_events for the bucket rather than incrementing, so re-running for
    # the same usage_date is always safe — never double-counts, never
    # duplicates rows (find_or_initialize_by + upsert on the unique index).
    class RollupJob < ApplicationJob
      def perform(usage_date = Date.yesterday)
        range = usage_date.all_day

        buckets = ControlPlane::UsageEvent.where(occurred_at: range)
          .group(:institution_id, :addon_id, :unit)
          .count

        buckets.each_key do |institution_id, addon_id, unit|
          scope = ControlPlane::UsageEvent.where(
            institution_id: institution_id, addon_id: addon_id, unit: unit, occurred_at: range
          )

          rollup = ControlPlane::UsageDailyRollup.find_or_initialize_by(
            institution_id: institution_id, addon_id: addon_id, unit: unit, usage_date: usage_date
          )
          rollup.total_quantity = scope.sum(:quantity)
          rollup.event_count = scope.count
          rollup.rolled_up_at = Time.current
          rollup.save!
        end
      end
    end
  end
end
