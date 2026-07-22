class CreateStudentPlacementsAndHpsTermSnapshots < ActiveRecord::Migration[8.1]
  # Slice 4 of guidelines/BI_DOCUMENT.md (HPS temporalidad año-a-año, §5.2/§7).
  #
  # THE PROBLEM (§5.2): students.section_id is a MUTABLE pointer to the current
  # group. Reorganizing sections overwrites the past, so BI can never answer
  # "how did this student's placement/affinity map change from 2° to 8°?"
  # (non-negotiable §1.1.3 — intra-student trends over time).
  #
  # TWO NET-NEW TENANT TABLES:
  #
  # 1) student_placements — owned by group_management (decision A1, §13; same
  #    ownership split as Slice 2's classroom_layouts/seat_assignments per A2:
  #    the domain that owns students/sections owns the write; analytics_bi only
  #    READS). Effective-dated + append-only: reassigning a student CLOSES the
  #    current row (valid_until = Date.current) and OPENS a new one — the exact
  #    symmetric "close the range" mold as Subscription#end!/Entitlement#revoke!
  #    (v1.33.0) and SeatAssigner/ClassroomReconfigurer (v1.36.0). Closing at
  #    Date.current (NOT "yesterday" as §5.2 sketched — deliberate correction,
  #    same as Slice 2): with a '[)' daterange, [from, today) and [today, ∞) are
  #    ADJACENT, never overlapping, so the GiST EXCLUDE is satisfied AND a move
  #    works even the same day a placement was opened. students.section_id stays
  #    as a LIVE CACHE of the current placement (many flows read it, §5.2).
  #
  # 2) hps_term_snapshots — owned by analytics_bi (§7 processing strategy:
  #    "snapshot for the 'over time'"). Congeals per-(student, academic_term)
  #    HPS state into a jsonb payload for cheap trend reads — same mold as
  #    report_cards.lines_snapshot / price_tiers_snapshot: the FK/leader columns
  #    are indexed/constrained; the derived, read-only metrics live in jsonb so
  #    later slices (5-8: character evals, affinities, family graph) can ADD
  #    payload fields WITHOUT a migration.
  def up
    # btree_gist supplies the equality operator classes (uuid) an EXCLUDE
    # constraint needs alongside the range's && operator. Already enabled by the
    # v1.33.0 billing migration; CREATE EXTENSION IF NOT EXISTS is idempotent,
    # so calling it here keeps this migration self-contained without depending
    # on migration order. The down does NOT drop it — billing + Slice 2
    # constraints still depend on it.
    enable_extension "btree_gist"

    # --- student_placements ------------------------------------------------
    create_table :student_placements, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :section, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :sections, on_delete: :cascade }
      t.references :grade_level, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :grade_levels, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      t.date :valid_from, null: false
      t.date :valid_until, null: true

      t.timestamps
    end

    # LEADER institution_id (TenantRlsGuardTest requires it) + the exact shape
    # the reassigner / analytics_bi read scope filter on: (institution, student,
    # valid_from) — "this student's placements over time" (§5.2 índices line).
    add_index :student_placements, %i[institution_id student_id valid_from],
      name: "idx_student_placements_on_inst_student_from"

    add_check_constraint :student_placements,
      "valid_until IS NULL OR valid_until >= valid_from",
      name: "student_placements_valid_range_check"

    # No two placements for the same (institution, student) may claim
    # overlapping calendar time — a student is in exactly ONE section at a time.
    # An open-ended row (valid_until NULL) becomes 'infinity' so it excludes any
    # placement starting after it (guardrail v1.33.0). Same mold as
    # subscriptions_no_overlapping_periods / classroom_layouts_no_overlapping_versions.
    execute <<~SQL
      ALTER TABLE student_placements
        ADD CONSTRAINT student_placements_no_overlapping_periods
        EXCLUDE USING gist (
          institution_id WITH =,
          student_id WITH =,
          daterange(valid_from, COALESCE(valid_until, 'infinity'::date), '[)') WITH &&
        );
    SQL

    enable_rls :student_placements

    # --- hps_term_snapshots ------------------------------------------------
    # One congealed HPS state per (student, academic_term). payload jsonb holds
    # the derived, read-only metrics (attendance/grade/heat/placement) so future
    # slices extend it without a migration (report_cards.lines_snapshot mold).
    create_table :hps_term_snapshots, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      # When the snapshot was computed (audit/debug). Not a filter — the
      # (student, term) triple is the identity, same as headcount's as_of_date.
      t.date :captured_on, null: false
      # Default '{}' so a snapshot with no computable signals is an explicit
      # empty object, never NULL (same posture as classroom_layouts.aisles).
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    # ONE snapshot per (student, term). LEADER institution_id (satisfies the
    # RLS guard) AND its (institution_id, student_id) prefix serves the trend
    # read "every snapshot for this student ordered by term" — no separate
    # index needed.
    add_index :hps_term_snapshots, %i[institution_id student_id academic_term_id],
      unique: true, name: "idx_hps_term_snapshots_one_per_student_term"

    enable_rls :hps_term_snapshots
  end

  def down
    disable_rls :hps_term_snapshots
    drop_table :hps_term_snapshots

    disable_rls :student_placements
    execute "ALTER TABLE student_placements DROP CONSTRAINT student_placements_no_overlapping_periods;"
    drop_table :student_placements
    # btree_gist intentionally NOT dropped — billing (v1.33.0) + Slice 2
    # constraints still depend on it.
  end
end
