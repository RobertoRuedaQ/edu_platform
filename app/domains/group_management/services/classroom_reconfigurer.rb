module GroupManagement
  # Opens or reconfigures a ClassroomLayout for a (section, academic_term),
  # append-only (BI_DOCUMENT.md §5.3, Slice 2). If a layout is already in
  # effect it is CLOSED (effective_until = Date.current) and a new one is
  # opened at version + 1; otherwise version 1 is opened. The old layout's
  # seat_assignments are left untouched — history is preserved.
  #
  # Closing at Date.current (not literally "yesterday" as §5.3's conceptual
  # ERD sketched) is the exact Subscription#end!/Entitlement#revoke! mold
  # (v1.33.0): with a '[)' daterange, [from, today) and [today, ∞) are
  # ADJACENT, never overlapping, so the GiST exclusion constraint is satisfied
  # AND it works even when a layout is reconfigured the same day it was created
  # (yesterday would violate the effective_until >= effective_from CHECK and
  # leave a one-day coverage hole).
  class ClassroomReconfigurer
    Result = Data.define(:layout, :previous)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(section:, academic_term:, rows:, cols:, board_orientation: 0, aisles: [], institution: Current.institution)
      @section = section
      @academic_term = academic_term
      @rows = rows
      @cols = cols
      @board_orientation = board_orientation
      @aisles = aisles
      @institution = institution
    end

    def call
      # requires_new: true -> a SAVEPOINT: a would-be overlap violation rolls
      # back only this unit and never poisons the caller's transaction.
      ActiveRecord::Base.transaction(requires_new: true) do
        previous = current_layout
        previous&.update!(effective_until: Date.current)
        layout = open_layout(next_version(previous))
        Result.new(layout: layout, previous: previous)
      end
    end

    private

    attr_reader :section, :academic_term, :rows, :cols, :board_orientation, :aisles, :institution

    def current_layout
      GroupManagement::ClassroomLayout
        .where(institution_id: institution.id, section_id: section.id, academic_term_id: academic_term.id)
        .current
        .first
    end

    def next_version(previous)
      previous ? previous.version + 1 : 1
    end

    def open_layout(version)
      GroupManagement::ClassroomLayout.create!(
        institution: institution, section: section, academic_term: academic_term,
        rows: rows, cols: cols, board_orientation: board_orientation, aisles: aisles,
        version: version, effective_from: Date.current
      )
    end
  end
end
