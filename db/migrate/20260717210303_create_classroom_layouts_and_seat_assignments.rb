class CreateClassroomLayoutsAndSeatAssignments < ActiveRecord::Migration[8.1]
  # Slice 2 of guidelines/BI_DOCUMENT.md (HPS Lente 1, "Mapa de Empatía
  # Espacial"). Physical classroom geometry (§5.3). Decision A2 (§13, owner-
  # approved): these two tables are owned by group_management (it owns the
  # physical classroom/section data — Section/GradeLevel/Student live here);
  # analytics_bi only READS them for the Lens 1 heat/dimming view, exactly the
  # way it already reads Schedules::Assessment/Attendance::AttendanceRecord
  # without owning them (§5.1).
  #
  # Both tables are effective-dated + append-only: reconfiguring mid-year
  # CLOSES the current row (effective_until) and OPENS a new one — the same
  # symmetric "close the range" mold as Subscription#end!/Entitlement#revoke!
  # (billing hardening v1.33.0). Old rows survive as history; nothing is ever
  # destroyed or overwritten.
  def up
    # btree_gist supplies the equality operator classes (uuid/smallint) an
    # EXCLUDE constraint needs alongside the range's && operator. Already
    # enabled by the v1.33.0 billing migration; enable_extension is idempotent
    # (CREATE EXTENSION IF NOT EXISTS), so calling it here keeps this migration
    # self-contained without depending on migration order. The down does NOT
    # drop it — the billing constraints still need it.
    enable_extension "btree_gist"

    # --- classroom_layouts -----------------------------------------------
    # One versioned geometry configuration per (section, academic_term).
    # aisles is PURE GEOMETRY (e.g. [{"after_col":2}]) — never PII. version
    # increments on each mid-year reconfiguration.
    create_table :classroom_layouts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :section, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :sections, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      t.integer :rows, limit: 2, null: false
      t.integer :cols, limit: 2, null: false
      # 0/90/180/270 — where the board sits relative to the drawn grid.
      t.integer :board_orientation, limit: 2, null: false, default: 0
      # Geometry only, never PII. Default '[]' so a layout without aisles is a
      # normal, explicit empty list rather than NULL.
      t.jsonb   :aisles, null: false, default: []
      t.integer :version, null: false, default: 1
      t.date    :effective_from, null: false
      t.date    :effective_until, null: true

      t.timestamps
    end

    # LEADER institution_id (TenantRlsGuardTest requires it) + the exact shape
    # AnalyticsBi::Lens::SpatialClassroomScope / the reconfigurer filter on:
    # (institution, section, term, effective_from).
    add_index :classroom_layouts, %i[institution_id section_id academic_term_id effective_from],
      name: "idx_classroom_layouts_on_inst_section_term_from"

    add_check_constraint :classroom_layouts, "rows > 0", name: "classroom_layouts_rows_positive_check"
    add_check_constraint :classroom_layouts, "cols > 0", name: "classroom_layouts_cols_positive_check"
    add_check_constraint :classroom_layouts, "board_orientation IN (0, 90, 180, 270)",
      name: "classroom_layouts_board_orientation_check"
    add_check_constraint :classroom_layouts, "effective_until IS NULL OR effective_until >= effective_from",
      name: "classroom_layouts_effective_range_check"

    # No two layouts for the same (institution, section, term) may claim
    # overlapping calendar time — enforces "one effective layout at a time"
    # AND the append-only versioning invariant at the DB level (same mold as
    # subscriptions_no_overlapping_periods, v1.33.0). An open-ended row
    # (effective_until NULL) becomes 'infinity' so it excludes anything
    # starting after it.
    execute <<~SQL
      ALTER TABLE classroom_layouts
        ADD CONSTRAINT classroom_layouts_no_overlapping_versions
        EXCLUDE USING gist (
          institution_id WITH =,
          section_id WITH =,
          academic_term_id WITH =,
          daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[)') WITH &&
        );
    SQL

    enable_rls :classroom_layouts

    # --- seat_assignments -------------------------------------------------
    # Who sits where, effective-dated. Moving a student mid-year CLOSES the old
    # assignment and OPENS a new one — old row untouched (append-only history).
    create_table :seat_assignments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :classroom_layout, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :classroom_layouts, on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.integer :row, limit: 2, null: false
      t.integer :col, limit: 2, null: false
      t.date    :effective_from, null: false
      t.date    :effective_until, null: true

      t.timestamps
    end

    # LEADER institution_id + the shape the read model filters on:
    # (institution, layout, effective_from).
    add_index :seat_assignments, %i[institution_id classroom_layout_id effective_from],
      name: "idx_seat_assignments_on_inst_layout_from"

    # "row" is a SQL reserved word — quote it in every raw expression.
    add_check_constraint :seat_assignments, '"row" >= 0', name: "seat_assignments_row_nonneg_check"
    add_check_constraint :seat_assignments, '"col" >= 0', name: "seat_assignments_col_nonneg_check"
    add_check_constraint :seat_assignments, "effective_until IS NULL OR effective_until >= effective_from",
      name: "seat_assignments_effective_range_check"

    # (§5.3) A single seat (row, col) can never hold two students at the same
    # time within one layout — no double-booking.
    execute <<~SQL
      ALTER TABLE seat_assignments
        ADD CONSTRAINT seat_assignments_no_double_booked_seat
        EXCLUDE USING gist (
          institution_id WITH =,
          classroom_layout_id WITH =,
          "row" WITH =,
          "col" WITH =,
          daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[)') WITH &&
        );
    SQL

    # (§5.3) A single student can never occupy two seats at the same time
    # within one layout.
    execute <<~SQL
      ALTER TABLE seat_assignments
        ADD CONSTRAINT seat_assignments_no_two_seats_per_student
        EXCLUDE USING gist (
          institution_id WITH =,
          classroom_layout_id WITH =,
          student_id WITH =,
          daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[)') WITH &&
        );
    SQL

    enable_rls :seat_assignments
  end

  def down
    disable_rls :seat_assignments
    execute "ALTER TABLE seat_assignments DROP CONSTRAINT seat_assignments_no_two_seats_per_student;"
    execute "ALTER TABLE seat_assignments DROP CONSTRAINT seat_assignments_no_double_booked_seat;"
    drop_table :seat_assignments

    disable_rls :classroom_layouts
    execute "ALTER TABLE classroom_layouts DROP CONSTRAINT classroom_layouts_no_overlapping_versions;"
    drop_table :classroom_layouts
    # btree_gist intentionally NOT dropped — the v1.33.0 billing constraints
    # still depend on it.
  end
end
