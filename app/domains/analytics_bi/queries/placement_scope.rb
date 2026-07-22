module AnalyticsBi
  # analytics_bi's READ side of the temporality axis (BI_DOCUMENT.md §5.2,
  # Slice 4). group_management OWNS student_placements (decision A1); this query
  # object reads them with an EXPLICIT institution filter (RLS is only the
  # backstop; no default_scope) — exactly the way SpatialClassroomScope already
  # reads GroupManagement::ClassroomLayout without owning it (§5.1).
  #
  # The whole point of the table: retrospective analysis joins by
  # academic_term_id, NEVER by students.section_id (which only knows the
  # present). "How did this student's section change from 2° to 8°?" is a read
  # of the ordered placement history, not the mutable cache column.
  class PlacementScope
    def initialize(institution: Current.institution)
      @institution = institution
    end

    # Full placement history for one student, oldest first — the raw material
    # for an intra-student trend (non-negotiable §1.1.3).
    def history_for(student)
      GroupManagement::StudentPlacement
        .where(institution_id: institution.id, student_id: student.id)
        .order(:valid_from)
    end

    # The placement that was in effect for a given (student, academic_term) —
    # what a per-term lens reads instead of the live section_id.
    def for_term(student:, academic_term:)
      GroupManagement::StudentPlacement
        .where(institution_id: institution.id, student_id: student.id,
          academic_term_id: academic_term.id)
        .order(:valid_from)
        .last
    end

    # Every student placed in a section during a term (the roster as it was,
    # not as it is now) — for a term-scoped classroom analysis.
    def students_in(section:, academic_term:)
      GroupManagement::StudentPlacement
        .where(institution_id: institution.id, section_id: section.id,
          academic_term_id: academic_term.id)
    end

    private

    attr_reader :institution
  end
end
