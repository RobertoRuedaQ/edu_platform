class CreateAssignments < ActiveRecord::Migration[8.1]
  # assignments (v1.21.0, item #6 of the MVP critical path, slice 1/4:
  # publish + view + grade directly). The grade lives ONLY in
  # schedules::Assessment (the one gradebook) — an assignment is a TEMPLATE
  # that, on publish, fans out to one Assessment row per enrolled student
  # (Assignments::Publisher), never a second grade store.
  #
  # Recon correction (see HISTORIA.md v1.21.0): Assessment belongs_to
  # :enrollment, not :subject, and the score already lives directly on that
  # row — there is no separate grade-entries table. A single
  # `assignments.assessment_id` FK (one row -> one Assessment) can't
  # represent a roster-wide assignment, so the FK goes the OTHER way:
  # assessments gains a nullable, additive assignment_id (same shape as
  # enrollments.academic_term_id, v1.15.0) — one assignment has_many
  # assessments, one per roster student.
  def change
    create_table :assignments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :subject, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :subjects, on_delete: :cascade }
      t.string :title, null: false
      t.text   :instructions
      # First-class, calendar-forward (no calendar view built this slice).
      t.date   :due_date, null: false
      # No "grade-entries" here — see the class-level comment.
      t.string :status, null: false, default: "draft"
      # Attribution only (nullable + nullify, same convention as
      # announcements.author_institution_user_id) — the assignment and its
      # fanned-out grades survive independent of who authored it.
      t.references :created_by_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }
      t.datetime :published_at

      t.timestamps
    end
    add_index :assignments, %i[institution_id subject_id status], name: "idx_assignments_on_institution_subject_status"

    add_check_constraint :assignments, "status IN ('draft','published','archived')", name: "assignments_status_check"

    enable_rls :assignments

    # Additive, nullable: most existing Assessment rows (manual grade entries
    # via Schedules::GradeEntriesController, v1.14.0) have no assignment at
    # all — that's a normal state, never backfilled by force (same discipline
    # as enrollments.academic_term_id). nullify, not cascade/restrict: an
    # assignment being archived (never hard-deleted while it has grades, see
    # HISTORIA.md) never touches these rows either way, but nullify is the
    # safe default if that policy ever changes.
    add_reference :assessments, :assignment, type: :uuid, null: true, index: true,
      foreign_key: { on_delete: :nullify }
  end
end
