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

  # Slice 5 (BI_DOCUMENT.md §5.4). Seeds the STARTER character framework +
  # peer_appreciation_tags using the doc's own §5.4 suggested content (curated,
  # constructive-only). Idempotent — safe to re-run. Stands in for a
  # framework-authoring UI, which is deferred until a real curation need (A5:
  # "curar con orientación pedagógica antes del Slice 5" — this is the boring
  # default). Usage: bin/rails bi:seed_character_starter[institution_id].
  STARTER_DIMENSIONS = %w[Lógica Creatividad Empatía Convivencia Perseverancia].freeze
  STARTER_LEVELS = [ "En desarrollo", "Consolidado", "Destacado" ].freeze
  STARTER_TAGS = {
    "Buen compañero"     => "convivencia",
    "Creativo/a"         => "creatividad",
    "Ayuda a los demás"  => "empatia",
    "Perseverante"       => "perseverancia",
    "Curioso/a"          => "logica"
  }.freeze

  desc "Seed the starter character framework + peer appreciation tags (Slice 5, §5.4). " \
       "Idempotent. Usage: bin/rails bi:seed_character_starter[institution_id] (all if omitted)."
  task :seed_character_starter, [ :institution_id ] => :environment do |_t, args|
    institutions = args[:institution_id].presence ? Core::Institution.where(id: args[:institution_id]) : Core::Institution.all

    institutions.find_each do |institution|
      Current.set(institution_id: institution.id) do
        ActiveRecord::Base.transaction do
          Tenant::Guc.set_local(institution.id)

          framework = AnalyticsBi::CharacterFramework.find_or_create_by!(
            institution: institution, name: "Marco de carácter (base)"
          ) do |f|
            f.description = "Marco base sugerido por BI_DOCUMENT.md §5.4."
            f.status = "published"
          end

          STARTER_DIMENSIONS.each_with_index do |name, position|
            dimension = AnalyticsBi::CharacterDimension.find_or_create_by!(
              institution: institution, framework: framework, name: name
            ) { |d| d.position = position; d.weight = 1 }

            STARTER_LEVELS.each_with_index do |label, level_position|
              AnalyticsBi::CharacterLevel.find_or_create_by!(
                institution: institution, dimension: dimension, label: label
              ) { |l| l.position = level_position }
            end
          end

          STARTER_TAGS.each do |label, category|
            AnalyticsBi::PeerAppreciationTag.find_or_create_by!(
              institution: institution, label: label
            ) { |tag| tag.category = category; tag.active = true }
          end
        end
      end
      puts "#{institution.name}: character starter seeded (framework + #{STARTER_TAGS.size} tags)"
    end
  end
end
