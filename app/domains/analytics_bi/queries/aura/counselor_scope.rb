module AnalyticsBi
  module Aura
    # Counselor-side read seam for Lens 5 (BI_DOCUMENT.md §5.7, Slice 3). Lists
    # the ACTIVE care_auras a counselor has published for one student, for the
    # counseling authoring surface. This is the sanctioned read counterpart to
    # AnalyticsBi::Aura::Projector (the write) — counseling calls THIS instead
    # of querying AnalyticsBi::CareAura directly, keeping counseling from
    # reaching into analytics_bi's internals.
    #
    # Explicit institution_id filter (RLS is only the backstop); no default_scope.
    # Returns the AR records (the counselor authored them and may see the
    # guidance/dates to manage them) — but these carry NO clinical data anyway,
    # they ARE the abstract projection.
    class CounselorScope
      def initialize(student:, institution: Current.institution)
        @student = student
        @institution = institution
      end

      def resolve
        AnalyticsBi::CareAura
          .where(institution_id: institution.id, student_id: student.id)
          .active
          .order(:aura_kind)
      end

      private

      attr_reader :student, :institution
    end
  end
end
