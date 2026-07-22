module AnalyticsBi
  module Lens
    # Teacher-side read for Lens 5 (BI_DOCUMENT.md §5.7, Slice 3), consumed by
    # AnalyticsBi::Lens::SpatialClassroom to overlay a discrete aura badge on
    # the Lens 1 seat grid. The teacher sees ONLY the abstract projection —
    # aura_kind + guidance_text + effective dates — never anything from
    # counseling, never even student PII beyond what the seat grid already shows.
    #
    # CLINICAL ISOLATION: this query touches care_auras and NOTHING else. It
    # maps every row to a 4-field Aura Data (kind/guidance/effective_from/
    # effective_until) — so the view can only ever interpolate those named
    # fields (explicit allowlist by construction, §6.2), never an AR model with
    # a traversable :student or any association reaching further. Explicit
    # institution_id filter; RLS is only the backstop; no default_scope.
    #
    # The RBAC gate (hps.aura.view for the section) is enforced by the caller
    # (SpatialClassroomsController#show via can?) BEFORE this is invoked — a
    # single section-level check covers every seated student, so there is no
    # per-row can? here (all seats belong to the one authorized section).
    class AuraScope
      Aura = Data.define(:kind, :guidance, :effective_from, :effective_until)

      def initialize(student_ids:, institution: Current.institution, on: Date.current)
        @student_ids = Array(student_ids).uniq
        @institution = institution
        @on = on
      end

      # => { student_id => [Aura, ...] }, only students with an active aura appear.
      def by_student
        return {} if student_ids.empty?

        AnalyticsBi::CareAura
          .where(institution_id: institution.id, student_id: student_ids)
          .effective_on(on)
          .order(:aura_kind)
          .group_by(&:student_id)
          .transform_values { |rows| rows.map { |row| project(row) } }
      end

      private

      attr_reader :student_ids, :institution, :on

      def project(row)
        Aura.new(kind: row.aura_kind, guidance: row.guidance_text,
          effective_from: row.effective_from, effective_until: row.effective_until)
      end
    end
  end
end
