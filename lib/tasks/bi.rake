# Slice 4 of guidelines/BI_DOCUMENT.md (HPS temporalidad año-a-año). Two manual
# triggers — the honest "no UI required yet" surface for this backend slice.
namespace :bi do
  desc "Backfill one open student_placement per active, placed student (Slice 4, §5.2). " \
       "Runs synchronously under each tenant's own GUC. Idempotent — safe to re-run " \
       "(also reconciles students created via roster import after the first run). " \
       "Usage: bin/rails bi:backfill_placements[institution_id] (all institutions if omitted)."
  task :backfill_placements, [ :institution_id ] => :environment do |_t, args|
    institutions = args[:institution_id].presence ? Core::Institution.where(id: args[:institution_id]) : Core::Institution.all

    institutions.find_each do |institution|
      # Set the tenant GUC on a real transaction so RLS lets the reads/writes
      # through and SET LOCAL clears at COMMIT (same idiom as qa_seed.rake).
      # SectionReassigner opens its own requires_new savepoint inside.
      result = Current.set(institution_id: institution.id) do
        ActiveRecord::Base.transaction do
          Tenant::Guc.set_local(institution.id)
          GroupManagement::PlacementBackfill.run(institution: institution)
        end
      end
      puts "#{institution.name}: placements=#{result.placed} skipped=#{result.skipped}"
    end
  end

  desc "Congeal HPS term snapshots for every active student (Slice 4, §7). Runs " \
       "synchronously under each tenant's own GUC (via ApplicationJob) — no worker " \
       "process required. Snapshots each institution's ACTIVE term; NOT on a recurring " \
       "schedule (end-of-term is a data-dependent event, not a fixed clock time). " \
       "Usage: bin/rails bi:snapshot_terms[institution_id] (all institutions if omitted)."
  task :snapshot_terms, [ :institution_id ] => :environment do |_t, args|
    institutions = args[:institution_id].presence ? Core::Institution.where(id: args[:institution_id]) : Core::Institution.all

    institutions.find_each do |institution|
      snapshots = AnalyticsBi::HpsTermSnapshotJob.run_now_for(institution)
      puts "#{institution.name}: hps_term_snapshots=#{snapshots.size}"
    end
  end
end
