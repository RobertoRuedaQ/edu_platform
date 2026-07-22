module Core
  module Headcount
    # Recurring fan-out (v1.32.0) — the entry config/recurring.yml actually
    # points at. SnapshotJob itself is per-institution (needs institution_id
    # set before #perform runs, see ApplicationJob's GUC machinery); Solid
    # Queue's recurring schedule can only point at ONE job with fixed args,
    # so this is the "for every institution" wrapper. Runs with no GUC of its
    # own (institutions is GLOBAL) — each SnapshotJob it enqueues carries its
    # own institution_id independently.
    class SnapshotAllJob < ApplicationJob
      def perform(as_of: Date.current)
        Core::Institution.find_each { |institution| SnapshotJob.enqueue_for(institution, as_of: as_of) }
      end
    end
  end
end
