module Calendar
  # THE single read path for a student/guardian portal timeline: real
  # Calendar::Event rows (Calendar::VisibleScope) MERGED with SYNTHETIC,
  # non-persisted entries derived from the assignments that student can see
  # (Assignments::StudentView.for, already filtered to `published`), using each
  # assignment's due_date as its date. Same "one computation, many surfaces"
  # discipline as Finance::AccountStatement/ReportCards::Computation.
  #
  # ASYMMETRY (documented in HISTORIA.md v1.27.0): this merge feeds ONLY the
  # student/guardian portal. Staff management (Calendar::EventsController#index)
  # shows ONLY real calendar_events via Calendar::ManageableScope, never the
  # merge — staff already see their assignment deadlines in the assignments UI,
  # and duplicating them here is exactly what the "un solo camino de lectura"
  # guardrail forbids.
  #
  # A derived deadline is NEVER a calendar_events row — it's a plain value
  # object (Entry, a Data). Both sources are wrapped into the SAME Entry shape
  # so the view iterates one type with no is_a? checks; `record` keeps the
  # underlying model available if a future surface needs it.
  module Timeline
    module_function

    # Sorted ascending by date. due_date is a Date, starts_at is a datetime —
    # to_time normalizes both for a stable comparison.
    def for(student:, institution: Current.institution)
      entries = event_entries(student, institution) + deadline_entries(student, institution)
      entries.sort_by { |entry| entry.starts_at.to_time }
    end

    def event_entries(student, institution)
      Calendar::VisibleScope.for(student: student, institution: institution).map do |event|
        Entry.new(title: event.title, starts_at: event.starts_at, source: :calendar_event, record: event)
      end
    end

    def deadline_entries(student, institution)
      Assignments::StudentView.for(student, institution: institution).map do |assignment|
        Entry.new(title: assignment.title, starts_at: assignment.due_date,
          source: :assignment_deadline, record: assignment)
      end
    end

    # A single uniform shape for both real events and derived deadlines. source
    # is what the view badges on; record is the underlying model (a
    # Calendar::Event or an Assignments::Assignment), never mutated here.
    Entry = Data.define(:title, :starts_at, :source, :record) do
      def assignment_deadline? = source == :assignment_deadline
    end
  end
end
