module Core
  module RosterImport
    # The SECOND job to exercise ApplicationJob's tenant-GUC-replication
    # machinery (first was Core::Headcount::SnapshotJob, S3a) — runs
    # Committer under the tenant's GUC (ApplicationJob wraps #perform in
    # `ActiveRecord::Base.transaction { Tenant::Guc.set_local(institution_id); ... }`),
    # so the upsert against `students` sees the right rows under RLS. No
    # `perform_later` call here sets Current.institution_id ahead of time
    # (this runs from a controller action, not a request that already has
    # one resolved via the GUC-setting concern), so callers MUST use
    # .enqueue_for — see SnapshotJob for the same convention.
    class CommitJob < ApplicationJob
      def self.enqueue_for(batch)
        job = new(batch_id: batch.id)
        job.institution_id = batch.institution_id
        job.enqueue
      end

      # Synchronous variant — same GUC handling via around_perform, just
      # without touching Solid Queue. Used by tests and the controller when
      # inline execution is preferable to waiting on a worker.
      def self.run_now_for(batch)
        job = new(batch_id: batch.id)
        job.institution_id = batch.institution_id
        job.perform_now
      end

      def perform(batch_id:)
        batch = Core::RosterImportBatch.find(batch_id)
        Core::RosterImport::Committer.call(batch: batch)
      end
    end
  end
end
