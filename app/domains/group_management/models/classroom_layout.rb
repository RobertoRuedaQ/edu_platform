module GroupManagement
  # Physical classroom geometry for one (section, academic_term), versioned and
  # effective-dated (BI_DOCUMENT.md §5.3, Slice 2). Owned by group_management
  # per decision A2 — analytics_bi only READS it (AnalyticsBi::Lens::
  # SpatialClassroomScope) to build the Lens 1 heat map.
  #
  # Append-only: reconfiguring mid-year closes this row (effective_until) and
  # opens version + 1 via GroupManagement::ClassroomReconfigurer — old
  # seat_assignments stay attached to the old layout, so history is preserved.
  # The DB enforces no two overlapping versions per (institution, section,
  # term) with a GiST exclusion constraint (same mold as billing v1.33.0).
  class ClassroomLayout < ApplicationRecord
    self.table_name = "classroom_layouts"

    BOARD_ORIENTATIONS = [ 0, 90, 180, 270 ].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :section, class_name: "GroupManagement::Section"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    has_many :seat_assignments, class_name: "GroupManagement::SeatAssignment",
             foreign_key: :classroom_layout_id, inverse_of: :classroom_layout, dependent: :destroy

    validates :rows, :cols, :version, :effective_from, presence: true
    validates :rows, :cols, numericality: { only_integer: true, greater_than: 0 }
    validates :board_orientation, inclusion: { in: BOARD_ORIENTATIONS }

    # NULL effective_until == currently in effect. current == the open version.
    scope :current, -> { where(effective_until: nil) }
    scope :effective_on, ->(date) {
      where("effective_from <= :d AND (effective_until IS NULL OR effective_until >= :d)", d: date)
    }

    def current?
      effective_until.nil?
    end
  end
end
