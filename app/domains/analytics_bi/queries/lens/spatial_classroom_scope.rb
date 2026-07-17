module AnalyticsBi
  module Lens
    # Index query object for Lens 1 (the spatial map). Lists the currently-in-
    # effect ClassroomLayouts for the institution's active term that the
    # observer is allowed to see (BI_DOCUMENT.md §9, Slice 2). Reads the
    # group_management-owned tables with an EXPLICIT institution_id filter and
    # per-row `context.can?` — the SAME molde #4 shape as
    # TeacherManagement::TeacherScope; no default_scope, RLS is only the
    # backstop. A grade-level-scoped grant covers a section via
    # section.grade_level_id; a group-scoped grant via section.group_id (== id)
    # — both handled for free by Authorization::Assignment::SCOPE_READERS.
    class SpatialClassroomScope
      def initialize(context:, institution: Current.institution)
        @context = context
        @institution = institution
      end

      def resolve
        term = active_term
        return [] if term.nil?

        GroupManagement::ClassroomLayout
          .where(institution_id: institution.id, academic_term_id: term.id)
          .current
          .includes(section: :grade_level)
          .to_a
          .select { |layout| context.can?("hps.classroom.view", layout.section) }
      end

      private

      attr_reader :context, :institution

      def active_term
        Core::AcademicTerm.active.where(institution_id: institution.id).first
      end
    end
  end
end
