module GroupManagement
  # Assigns or moves a student to a seat (row, col) in a ClassroomLayout,
  # append-only (BI_DOCUMENT.md §5.3, Slice 2). The student's current active
  # seat in this layout (if any) is CLOSED before the new one is opened, so a
  # move never trips the "one active seat per student" exclusion constraint.
  # Closing at Date.current makes the ranges adjacent, never overlapping (same
  # mold as ClassroomReconfigurer).
  #
  # Double-booking a seat that ANOTHER active student already holds, or any
  # other overlap the DB forbids, raises ActiveRecord::StatementInvalid
  # (exclusion_violation) — the DB is the backstop, never a race-prone
  # application check.
  class SeatAssigner
    def self.call(**kwargs)
      new(**kwargs).call
    end

    # Closes a student's active seat in a layout without opening a new one.
    def self.unassign(layout:, student:, institution: Current.institution)
      GroupManagement::SeatAssignment
        .where(institution_id: institution.id, classroom_layout_id: layout.id, student_id: student.id)
        .active
        .update_all(effective_until: Date.current)
    end

    def initialize(layout:, student:, row:, col:, institution: Current.institution)
      @layout = layout
      @student = student
      @row = row
      @col = col
      @institution = institution
    end

    def call
      # requires_new: true -> a SAVEPOINT, so a double-booking exclusion
      # violation rolls back only this unit and re-raises WITHOUT poisoning the
      # caller's surrounding transaction (the request's TenantScoped tx). The
      # controller can then rescue StatementInvalid and redirect cleanly.
      ActiveRecord::Base.transaction(requires_new: true) do
        close_current_seat
        open_seat
      end
    end

    private

    attr_reader :layout, :student, :row, :col, :institution

    def close_current_seat
      GroupManagement::SeatAssignment
        .where(institution_id: institution.id, classroom_layout_id: layout.id, student_id: student.id)
        .active
        .update_all(effective_until: Date.current)
    end

    def open_seat
      GroupManagement::SeatAssignment.create!(
        institution: institution, classroom_layout: layout, student: student,
        row: row, col: col, effective_from: Date.current
      )
    end
  end
end
