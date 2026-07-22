module AnalyticsBi
  module Character
    # Publishes a staff-authored character evaluation and FREEZES the framework
    # structure into framework_snapshot — the same freeze discipline as
    # Assignments::Publisher / ReportCards::Publisher / Subscription#sign!.
    # Nothing downstream re-reads the live framework afterward; only the snapshot.
    #
    # STAFF authorship (T2) — gated by hps.character.author at the controller.
    # NO consent gate here: the character instrument is the professional,
    # human-authored rubric-mold evaluation (§1.1.2), not the peer/guardian NNA
    # interaction that §5.4 point 5 gates on guardian consent. Consent lives on
    # AnalyticsBi::Character::PeerAppreciationRecorder only.
    #
    # selections is [{ dimension_key:, level_label:, note: }] — each validated
    # against the FROZEN snapshot (the key must be a dimension in the snapshot,
    # the label a level of that dimension), so a score can never reference
    # structure that was not published.
    class Publisher
      Result = Data.define(:evaluation)

      InvalidSelection = Class.new(StandardError)

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(framework:, student:, academic_term:, author:, selections:,
                     author_kind: "teacher", institution: Current.institution)
        @framework = framework
        @student = student
        @academic_term = academic_term
        @author = author
        @selections = selections
        @author_kind = author_kind
        @institution = institution
      end

      def call
        snapshot = framework.snapshot

        # requires_new: true -> a SAVEPOINT, so a would-be unique violation (the
        # same author re-evaluating the same student/term/framework) rolls back
        # only this unit and re-raises without poisoning the caller's request
        # transaction. Same posture as SeatAssigner / Aura::Projector.
        ActiveRecord::Base.transaction(requires_new: true) do
          evaluation = AnalyticsBi::CharacterEvaluation.create!(
            institution: institution, student: student, academic_term: academic_term,
            framework: framework, framework_snapshot: snapshot,
            author: author, author_kind: author_kind,
            status: "published", published_at: Time.current
          )
          build_scores(evaluation, snapshot)
          Result.new(evaluation: evaluation)
        end
      end

      private

      attr_reader :framework, :student, :academic_term, :author, :selections,
        :author_kind, :institution

      def build_scores(evaluation, snapshot)
        dimensions = snapshot.fetch("dimensions", []).index_by { |d| d["key"].to_s }

        Array(selections).each do |selection|
          key = selection[:dimension_key].to_s
          label = selection[:level_label].to_s
          dimension = dimensions[key]
          raise InvalidSelection, "dimensión desconocida: #{key}" if dimension.nil?
          unless dimension["levels"].any? { |level| level["label"] == label }
            raise InvalidSelection, "nivel desconocido para la dimensión: #{label}"
          end

          evaluation.character_dimension_scores.create!(
            institution: institution, dimension_key: key,
            level_label: label, note: selection[:note].presence
          )
        end
      end
    end
  end
end
