module Core
  module RosterImport
    # Full-async hardening (OPEN_PROCESS.md item #1): #create used to run
    # Parser+Validator inline, blocking the admin's upload request. Same
    # dual enqueue_for/run_now_for + GUC contract as CommitJob (ApplicationJob
    # wraps #perform in Tenant::Guc.set_local under a transaction) — see
    # CommitJob for why callers MUST use .enqueue_for/.run_now_for instead of
    # perform_later/perform_now directly.
    #
    # `pending_content` (encrypted, see RosterImportBatch) is the CSV body the
    # controller could no longer hand off in memory once parsing moved off
    # the request thread — cleared here right after Parser has read it, so
    # the plaintext window is exactly one successful job attempt.
    class ParseAndValidateJob < ApplicationJob
      def self.enqueue_for(batch)
        job = new(batch_id: batch.id)
        job.institution_id = batch.institution_id
        job.enqueue
      end

      def self.run_now_for(batch)
        job = new(batch_id: batch.id)
        job.institution_id = batch.institution_id
        job.perform_now
      end

      def perform(batch_id:)
        batch = Core::RosterImportBatch.find(batch_id)
        return if batch.roster_import_rows.exists? # idempotency guard — a re-run must not duplicate rows

        Core::RosterImport::Parser.call(batch: batch, content: batch.pending_content)
        Core::RosterImport::Validator.call(batch: batch)
        batch.update!(pending_content: nil)
      end
    end
  end
end
