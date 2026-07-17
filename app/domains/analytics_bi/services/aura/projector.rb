module AnalyticsBi
  module Aura
    # THE single sanctioned cross-domain write seam for Lens 5 (BI_DOCUMENT.md
    # §5.7, Slice 3). Invoked FROM counseling (Counseling::CareAurasController):
    # counseling owns the diagnosis and decides to publish a projection; this
    # service writes the analytics_bi-owned care_auras row. analytics_bi never
    # reads counseling's tables; counseling never touches AnalyticsBi::CareAura
    # directly — it calls this (write) and AnalyticsBi::Aura::CounselorScope
    # (read). guidance_text carries ZERO clinical PII by construction of the
    # workflow (the counselor authors it; the invariant is procedural, not a
    # technical scanner).
    #
    # Append-only, symmetric "close the range" mold (Subscription#end!/
    # Entitlement#revoke!/SeatAssigner): publishing a kind that already has an
    # ACTIVE projection CLOSES the old one (effective_until = Date.current) and
    # OPENS the new one, so guidance history is preserved. Closing at
    # Date.current keeps [from, today) and [today, ∞) adjacent — never a same-
    # day CHECK violation, never a coverage hole.
    class Projector
      Result = Data.define(:aura, :previous)

      def self.call(**kwargs)
        new(**kwargs).call
      end

      # Retires an active aura (sets effective_until) — the counselor's "quitar"
      # action. Idempotent: a already-closed aura is left untouched.
      def self.retire(aura:)
        aura.update!(effective_until: Date.current) if aura.active?
        aura
      end

      def initialize(student:, academic_term:, aura_kind:, guidance_text:, authored_by:,
                     effective_from: Date.current, effective_until: nil, institution: Current.institution)
        @student = student
        @academic_term = academic_term
        @aura_kind = aura_kind
        @guidance_text = guidance_text
        @authored_by = authored_by
        @effective_from = effective_from
        @effective_until = effective_until
        @institution = institution
      end

      def call
        # requires_new: true -> a SAVEPOINT: a would-be unique violation (a race
        # to publish the same active kind) rolls back only this unit and re-
        # raises without poisoning the caller's request transaction.
        ActiveRecord::Base.transaction(requires_new: true) do
          previous = active_aura_of_kind
          previous&.update!(effective_until: Date.current)
          aura = AnalyticsBi::CareAura.create!(
            institution: institution, student: student, academic_term: academic_term,
            aura_kind: aura_kind, guidance_text: guidance_text,
            authored_by_counselor: authored_by,
            effective_from: effective_from, effective_until: effective_until
          )
          Result.new(aura: aura, previous: previous)
        end
      end

      private

      attr_reader :student, :academic_term, :aura_kind, :guidance_text, :authored_by,
        :effective_from, :effective_until, :institution

      def active_aura_of_kind
        AnalyticsBi::CareAura
          .where(institution_id: institution.id, student_id: student.id, aura_kind: aura_kind)
          .active
          .first
      end
    end
  end
end
