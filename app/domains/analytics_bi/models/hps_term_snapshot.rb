module AnalyticsBi
  # One congealed HPS state per (student, academic_term) — the cheap-trend-read
  # snapshot mold (BI_DOCUMENT.md §7, Slice 4). OWNED by analytics_bi (the "over
  # time" half of the temporality axis; student_placements is the "when" axis it
  # hangs off). Written by AnalyticsBi::Hps::Snapshotter via the
  # HpsTermSnapshotJob/HpsTermSnapshotAllJob fan-out pair (guardrail v1.32.0),
  # read by AnalyticsBi::HpsTermSnapshotScope (Slice 6 consumes it for the
  # character-card trend view).
  #
  # payload is a jsonb bag of DERIVED, read-only metrics (attendance/grade/heat/
  # placement for that term) — same mold as report_cards.lines_snapshot /
  # price_tiers_snapshot: the identity/FK columns are indexed & constrained; the
  # metrics live in jsonb so later slices (5-8: character evals, affinities,
  # family graph) can ADD payload keys WITHOUT a migration. Nothing in the
  # payload is ever a filter or a join key — only the (institution, student,
  # term) triple is.
  class HpsTermSnapshot < ApplicationRecord
    self.table_name = "hps_term_snapshots"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"

    validates :captured_on, presence: true
    # One snapshot per (student, term) — backed by the DB unique index
    # idx_hps_term_snapshots_one_per_student_term (the real backstop; this is
    # only for a friendly error). allow_nil so Rails does not treat a nil
    # academic_term_id as a duplicate.
    validates :academic_term_id, uniqueness: { scope: %i[institution_id student_id], allow_nil: true }

    # Convenience readers over the jsonb payload — never persisted columns, so
    # the snapshot shape can grow without touching the schema.
    def attendance_rate = payload["attendance_rate"]
    def average_grade   = payload["average_grade"]
    def heat            = payload["heat"]
    def section_name    = payload["section_name"]
  end
end
