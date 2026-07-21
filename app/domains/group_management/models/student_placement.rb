module GroupManagement
  # One student's placement in a section for an academic term, effective-dated
  # and append-only (BI_DOCUMENT.md §5.2, Slice 4). OWNED by group_management
  # (decision A1 — the domain that owns students/sections owns the write; same
  # ownership split as Slice 2's classroom_layouts/seat_assignments per A2).
  # analytics_bi only READS this (AnalyticsBi::PlacementScope) for year-over-year
  # trend analysis, joining by academic_term_id — never re-deriving from
  # students.section_id, which only ever knows the PRESENT.
  #
  # students.section_id stays as a LIVE CACHE of the current placement (§5.2 —
  # many flows already read it); it is not removed. The single write seam that
  # keeps the cache and this table in lock-step is GroupManagement::SectionReassigner.
  #
  # Append-only: reassigning a student CLOSES the current row (valid_until =
  # Date.current) and OPENS a new one — the old row is never overwritten. A GiST
  # exclusion constraint (student_placements_no_overlapping_periods) enforces at
  # the DB level that a student never has two overlapping active placements.
  class StudentPlacement < ApplicationRecord
    self.table_name = "student_placements"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :section, class_name: "GroupManagement::Section"
    belongs_to :grade_level, class_name: "GroupManagement::GradeLevel"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"

    validates :valid_from, presence: true

    # NULL valid_until == currently in effect (same convention as
    # SeatAssignment/CareAura). current == the open placement.
    scope :current, -> { where(valid_until: nil) }
    scope :effective_on, ->(date) {
      where("valid_from <= :d AND (valid_until IS NULL OR valid_until >= :d)", d: date)
    }

    def current?
      valid_until.nil?
    end
  end
end
