module Core
  module Headcount
    # The FIRST job to actually exercise ApplicationJob's tenant-GUC-replication
    # machinery (attr_accessor :institution_id + serialize/deserialize +
    # around_perform) — that scaffold existed since the initial commit but had
    # never been used or tested until this slice (S3a, PROJECT_STATE.md §9.7-7).
    #
    # Runs WITH the tenant's GUC fixed (G1/G6) — ApplicationJob wraps #perform
    # in `ActiveRecord::Base.transaction { Tenant::Guc.set_local(institution_id); ... }`,
    # so Core::Headcount::Snapshotter's tenant-scoped queries see the right
    # rows under RLS. The transaction commits at the end of #perform, which is
    # what actually clears the SET LOCAL — verified empirically (a naive re-read
    # of current_setting() inside the same connection can be fooled by AR's
    # query cache; the real proof is a subsequent RLS-scoped query seeing zero
    # rows with no GUC set — see the test for this job).
    #
    # No `perform_later` call in this slice sets Current.institution_id ahead of
    # time (there's no request), so callers MUST use .enqueue_for — see below.
    class SnapshotJob < ApplicationJob
      def self.enqueue_for(institution, as_of: Date.current)
        job = new(as_of: as_of)
        job.institution_id = institution.id
        job.enqueue
      end

      # Synchronous variant (still goes through around_perform's GUC handling,
      # just without touching Solid Queue) — what the manual rake trigger uses,
      # so running it doesn't silently depend on a worker process being up.
      def self.run_now_for(institution, as_of: Date.current)
        job = new(as_of: as_of)
        job.institution_id = institution.id
        job.perform_now
      end

      def perform(as_of: Date.current)
        institution = Core::Institution.find(institution_id)
        Core::Headcount::Snapshotter.call(institution: institution, as_of: as_of)
      end
    end
  end
end
