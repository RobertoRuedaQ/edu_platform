module AnalyticsBi
  module Character
    # The AGGREGATE-ONLY read-model for peer appreciations (BI_DOCUMENT.md §5.4
    # resguardos #2 and #3). This is the ONLY sanctioned read path the (future,
    # Slice 6) portal ficha will consume — it exists now, tested, even though
    # nothing renders it yet.
    #
    # HARD invariants baked in by construction:
    #  - Never attributable: it returns tag_label / category / count ONLY. There
    #    is no way to reach a giver_student_id / giver_guardian_user_id through
    #    this projection (§5.4 resguardo #3 — only hps.character.moderate sees
    #    attribution, via the raw rows + audit).
    #  - Threshold before surfacing: a tag appears ONLY once it has at least
    #    PeerAppreciationRecorder::AGGREGATION_THRESHOLD distinct legitimate
    #    (active) contributions. The partial unique index guarantees one active
    #    row per (student, tag, giver), so an active-row count IS a distinct-giver
    #    count. Withheld rows never count.
    #
    # In-memory over indexed AR (§7 default). Explicit institution_id filter (no
    # default_scope); RLS is the backstop.
    class PeerAppreciationDigest
      Recognition = Data.define(:tag_label, :category, :count)

      def self.for(**kwargs)
        new(**kwargs).recognitions
      end

      def initialize(student:, academic_term: nil, institution: Current.institution,
                     threshold: PeerAppreciationRecorder::AGGREGATION_THRESHOLD)
        @student = student
        @academic_term = academic_term
        @institution = institution
        @threshold = threshold
      end

      def recognitions
        counts_by_tag
          .select { |_tag_id, count| count >= threshold }
          .filter_map do |tag_id, count|
            tag = tags[tag_id]
            next if tag.nil?

            Recognition.new(tag_label: tag.label, category: tag.category, count: count)
          end
          .sort_by { |recognition| [ -recognition.count, recognition.tag_label ] }
      end

      private

      attr_reader :student, :academic_term, :institution, :threshold

      def counts_by_tag
        scope = AnalyticsBi::PeerAppreciation
          .active
          .where(institution_id: institution.id, student_id: student.id)
        scope = scope.where(academic_term_id: academic_term.id) if academic_term
        scope.group(:tag_id).count
      end

      def tags
        @tags ||= AnalyticsBi::PeerAppreciationTag
          .where(institution_id: institution.id, id: counts_by_tag.keys)
          .index_by(&:id)
      end
    end
  end
end
