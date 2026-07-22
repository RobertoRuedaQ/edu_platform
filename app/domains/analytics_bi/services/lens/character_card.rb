module AnalyticsBi
  module Lens
    # Lens 2 read-model — the "Ficha de Personaje" (BI_DOCUMENT.md §5.4 "Cómo
    # alimenta las lentes", Slice 6). A pure CONSUMER of the Slice 5 machinery:
    # it assembles ONE student's card from the staff CharacterEvaluation (radar +
    # brújula), the aggregate-only PeerAppreciationDigest (medallas) and the
    # intra-student growth over terms (§1.1.3). In-memory over indexed AR (§7);
    # explicit institution_id filter, no default_scope. RLS is the backstop.
    #
    # HARD invariant (§1.1.2 / §1.1.4): the ordinal level position is ONLY a
    # geometry input for AnalyticsBi::Svg::RadarChart. It is NEVER rendered to
    # the user — every visible/accessible field on the Card is qualitative text
    # (level_label + descriptor), never a number/score. Empty state is a real
    # absence (axes == []), never a fake flat/zeroed radar.
    class CharacterCard
      Axis = Data.define(:dimension_name, :level_label, :descriptor, :ordinal, :levels_count)
      GrowthEntry = Data.define(:term_name, :term_starts_on, :axes)
      Card = Data.define(:student_name, :axes, :top_strengths, :recognitions, :growth) do
        def evaluated? = axes.any?
      end

      def self.call(**kwargs) = new(**kwargs).call

      def initialize(student:, institution: Current.institution)
        @student = student
        @institution = institution
      end

      def call
        Card.new(student_name: student_name, axes: radar_axes, top_strengths: top_strengths,
          recognitions: recognitions, growth: growth)
      end

      private

      attr_reader :student, :institution

      def student_name
        "#{student.first_name} #{student.last_name}"
      end

      # The radar reflects the MOST RECENT published evaluation only (§5.4).
      def radar_axes
        latest_published ? axes_from(latest_published) : []
      end

      # "Fortalezas más consolidadas" (§5.4): the dimensions at the highest
      # observed level, by NAME only — descriptive, never a computed verdict.
      def top_strengths
        return [] if radar_axes.empty?

        peak = radar_axes.map(&:ordinal).max
        radar_axes.select { |axis| axis.ordinal == peak }.map(&:dimension_name)
      end

      def recognitions
        AnalyticsBi::Character::PeerAppreciationDigest.for(student: student, institution: institution)
      end

      # Intra-student growth (§1.1.3): one snapshot per term, oldest term first,
      # ordered by the term's OWN calendar start (HpsTermSnapshotScope mold) so
      # re-publishing never reorders history. Not a trend line of one score.
      def growth
        latest_per_term.map { |evaluation| growth_entry(evaluation) }
      end

      def growth_entry(evaluation)
        GrowthEntry.new(term_name: evaluation.academic_term.name,
          term_starts_on: evaluation.academic_term.starts_on, axes: axes_from(evaluation))
      end

      def latest_per_term
        published_evaluations
          .group_by(&:academic_term_id).values
          .map { |evals| evals.max_by(&:published_at) }
          .sort_by { |evaluation| evaluation.academic_term.starts_on }
      end

      def latest_published
        published_evaluations.max_by(&:published_at)
      end

      def published_evaluations
        @published_evaluations ||= AnalyticsBi::CharacterEvaluation.published
          .where(institution_id: institution.id, student_id: student.id)
          .includes(:academic_term, :character_dimension_scores).to_a
      end

      # Maps a FROZEN framework_snapshot + this evaluation's chosen levels to one
      # radar axis per dimension. ordinal = the chosen level's index within its
      # dimension's levels array — the SVG's radius input, NEVER shown.
      def axes_from(evaluation)
        chosen = evaluation.character_dimension_scores.index_by(&:dimension_key)
        dimensions(evaluation).filter_map do |dimension|
          score = chosen[dimension["key"].to_s]
          score && axis_for(dimension, score)
        end
      end

      def axis_for(dimension, score)
        levels = Array(dimension["levels"])
        ordinal = levels.index { |level| level["label"] == score.level_label } || 0
        Axis.new(dimension_name: dimension["name"], level_label: score.level_label,
          descriptor: levels.dig(ordinal, "descriptor"), ordinal: ordinal, levels_count: levels.size)
      end

      def dimensions(evaluation)
        Array(evaluation.framework_snapshot["dimensions"])
      end
    end
  end
end
