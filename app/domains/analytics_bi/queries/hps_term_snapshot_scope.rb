module AnalyticsBi
  # Read side of the HPS term snapshots (BI_DOCUMENT.md §7, Slice 4). Slice 6
  # (the character card / trend view) consumes this; today it is the minimal,
  # real query object that reads the congealed snapshots with an EXPLICIT
  # institution filter (RLS is only the backstop; no default_scope) — same
  # discipline as every analytics_bi read object.
  #
  # The trends read (§1.1.3 — intra-student over time) is exactly the prefix of
  # the unique index (institution_id, student_id): every snapshot for a student,
  # ordered by term, cheaply.
  class HpsTermSnapshotScope
    def initialize(institution: Current.institution)
      @institution = institution
    end

    # Every snapshot for one student, chronological by term start — the raw
    # material for a sparkline / trend line. Ordered by the term's own calendar
    # start, not captured_on, so re-snapshotting a term never reorders history.
    def trend_for(student)
      AnalyticsBi::HpsTermSnapshot
        .where(institution_id: institution.id, student_id: student.id)
        .joins(:academic_term)
        .order("academic_terms.starts_on")
    end

    # The single snapshot for a (student, term), or nil.
    def for_term(student:, academic_term:)
      AnalyticsBi::HpsTermSnapshot.find_by(
        institution_id: institution.id, student_id: student.id, academic_term_id: academic_term.id
      )
    end

    private

    attr_reader :institution
  end
end
