module AnalyticsBi
  # Per-institution job that congeals the HPS term snapshot for every active
  # student (BI_DOCUMENT.md §7, Slice 4). Same mold as
  # Core::Headcount::SnapshotJob: it rides ApplicationJob's tenant-GUC machinery
  # (institution_id + serialize/deserialize + around_perform wraps #perform in a
  # transaction with the GUC set), so AnalyticsBi::Hps::Snapshotter's tenant-
  # scoped reads/writes see the right rows under RLS.
  #
  # academic_term_id is OPTIONAL: nil resolves the institution's currently active
  # term inside #perform (under the job's own GUC). An explicit term lets an
  # end-of-term trigger snapshot a term that has since closed. If no term
  # resolves (institution has no active term and none was passed), it is a quiet
  # no-op — never an error (the common off-season case).
  #
  # NOT wired into config/recurring.yml: an end-of-term snapshot is a
  # data-dependent event, not a fixed clock time (see BI_DOCUMENT §14/OPEN_PROCESS
  # — invoke manually via `bin/rails bi:snapshot_terms` or the fan-out below until
  # a term-close trigger exists).
  class HpsTermSnapshotJob < ApplicationJob
    def self.enqueue_for(institution, academic_term: nil)
      job = new(academic_term_id: academic_term&.id)
      job.institution_id = institution.id
      job.enqueue
    end

    # Synchronous variant (still goes through around_perform's GUC handling) —
    # what the manual rake trigger uses, so it doesn't silently depend on a
    # worker process being up. Same posture as SnapshotJob.run_now_for.
    def self.run_now_for(institution, academic_term: nil)
      job = new(academic_term_id: academic_term&.id)
      job.institution_id = institution.id
      job.perform_now
    end

    def perform(academic_term_id: nil)
      institution = Core::Institution.find(institution_id)
      term = resolve_term(institution, academic_term_id)
      return [] if term.nil?

      AnalyticsBi::Hps::Snapshotter.call(institution: institution, academic_term: term)
    end

    private

    def resolve_term(institution, academic_term_id)
      if academic_term_id
        Core::AcademicTerm.find_by(institution_id: institution.id, id: academic_term_id)
      else
        Core::AcademicTerm.active.find_by(institution_id: institution.id)
      end
    end
  end
end
