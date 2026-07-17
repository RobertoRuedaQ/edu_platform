class CreateCalendarEvents < ActiveRecord::Migration[8.1]
  # calendar (net-new domain, v1.27.0, item #7 of the MVP critical path).
  # Shared calendar with caregivers. Audience is expressed with TWO mutually-
  # exclusive scope columns (same language as role_assignments.scope_*): both
  # null => institution-wide. Deliberately NO `kind` column — the only creator
  # is this domain; assignment deadlines are DERIVED in memory (never a row),
  # and there's no real data source for activity/term events yet. If ever
  # needed, it's added additively (see HISTORIA.md v1.27.0).
  def change
    create_table :calendar_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text   :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at,   null: false
      # Audience: two mutually-exclusive scope columns, same idiom as
      # role_assignments.scope_*. Both null => the event is institution-wide.
      # CASCADE mirrors role_assignments' own scope FKs: if the grade/section
      # goes away, an event scoped to it has no audience left.
      t.references :scope_grade_level, type: :uuid, null: true, index: true,
        foreign_key: { to_table: :grade_levels, on_delete: :cascade }
      t.references :scope_group, type: :uuid, null: true, index: true,
        foreign_key: { to_table: :sections, on_delete: :cascade }
      # Attribution only (nullable + nullify) — same convention as
      # conversations.created_by_institution_user_id: the event survives
      # independent of who created it.
      t.references :created_by_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }

      t.timestamps
    end

    # Index LED by institution_id (required by TenantRlsGuardTest — see
    # HISTORIA.md v1.26.0) that ALSO serves chronological ordering: one index
    # covers both the tenant-isolation guard and the timeline's `order(:starts_at)`.
    add_index :calendar_events, %i[institution_id starts_at],
      name: "index_calendar_events_on_institution_and_starts_at"

    add_check_constraint :calendar_events, "ends_at >= starts_at",
      name: "calendar_events_time_order_check"
    # An event is EITHER grade-scoped OR group-scoped OR institution-wide —
    # never both scope columns at once (defense in depth alongside the model
    # validation, same criterion as Assignment#lock_group_work_after_publish).
    add_check_constraint :calendar_events,
      "NOT (scope_grade_level_id IS NOT NULL AND scope_group_id IS NOT NULL)",
      name: "calendar_events_scope_exclusive_check"

    enable_rls :calendar_events
  end
end
