module AnalyticsBi
  # Read side of "my current section co-members" for the Lens 2 peer-giving
  # picker (BI_DOCUMENT.md §1.1.6 — the picker is a CLOSED list, NEVER a
  # name/document search or a navigable directory of minors). A Query object
  # with an EXPLICIT institution filter and no default_scope (RLS is only the
  # backstop) — same discipline as AnalyticsBi::PlacementScope.
  #
  # It reads the LIVE section cache (students.section_id, §5.2 — the present-time
  # placement that many flows already read), NOT PlacementScope#students_in:
  # that returns term-scoped StudentPlacement rows for retrospective analysis,
  # whereas the peer picker is a present-time roster of who shares the giver's
  # section RIGHT NOW. Indexed by index_students_on_section_id.
  class SectionClassmatesScope
    def initialize(institution: Current.institution)
      @institution = institution
    end

    # Every OTHER active student sharing this student's current section. An
    # empty relation when the giver has no section, so an unplaced student
    # simply has no one to recognize (never an error, never an open lookup).
    def for(student)
      return GroupManagement::Student.none if student.section_id.nil?

      GroupManagement::Student
        .where(institution_id: institution.id, section_id: student.section_id, status: "active")
        .where.not(id: student.id)
        .order(:last_name, :first_name)
    end

    private

    attr_reader :institution
  end
end
