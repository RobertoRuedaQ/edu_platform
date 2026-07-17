module GroupManagement
  # One student's seat (row, col) in a ClassroomLayout, effective-dated
  # (BI_DOCUMENT.md §5.3, Slice 2). Append-only: moving a student closes the
  # old row and opens a new one (GroupManagement::SeatAssigner) — the old row
  # is never overwritten or destroyed. Two GiST exclusion constraints enforce
  # at the DB level, per layout: (1) a seat can't hold two students at once,
  # (2) a student can't hold two seats at once.
  class SeatAssignment < ApplicationRecord
    self.table_name = "seat_assignments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :classroom_layout, class_name: "GroupManagement::ClassroomLayout", inverse_of: :seat_assignments
    belongs_to :student, class_name: "GroupManagement::Student"

    validates :row, :col, :effective_from, presence: true
    validates :row, :col, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :active, -> { where(effective_until: nil) }
    scope :effective_on, ->(date) {
      where("effective_from <= :d AND (effective_until IS NULL OR effective_until >= :d)", d: date)
    }

    def active?
      effective_until.nil?
    end
  end
end
