class CreateTransportationAndWireRouteScope < ActiveRecord::Migration[8.1]
  # guidelines/CLOSURE_PLAN.md Fase D (third increment): retires the whole
  # `transportation` domain from 100% stub (`RouteRoster`/`RiderRoster`,
  # `Data.define` hardcoded rows) — the worst kind of gap this session found,
  # since "Rutas"/"Abordaje" already have live nav entries + real
  # controllers/routes wired on top of that fake data (a visible dead end,
  # not an invisible one).
  #
  # Four net-new tenant-scoped tables:
  #
  # 1) routes — driver is a REAL StaffManagement::StaffMember (nullable FK,
  #    on_delete: nullify, exact molde of Extracurriculars::Activity's
  #    instructor_staff_member_id) confirmed by the owner over free text —
  #    staff_members.staff_category already has a 'transport' value in its
  #    CHECK from day one, so the schema anticipated this.
  #
  # 2) route_stops — ordered stops within a route; unique (route_id,
  #    position) so two stops can never claim the same slot.
  #
  # 3) route_riders — student <-> route, WITH a `shift` (am/pm) confirmed by
  #    the owner: a student can have a different route (or none) in the
  #    morning vs. the afternoon, never a single row assumed to cover both.
  #    Unique (institution, student, shift) — a student can't ride two buses
  #    in the same shift, but CAN ride different routes across shifts.
  #
  # 4) boarding_events — append-only (no status, no update/destroy route),
  #    same posture as StudentSupport::DisciplinaryLog: recorded_by is
  #    identity-accountable (RESTRICT), event_type is a closed enum.
  #    BoardingEventsController#create was a literal no-op before this
  #    (flash "(stub)", nothing persisted) — this is the other half of the
  #    dead end this increment closes, alongside routes/riders.
  #
  # Plus: wires the `:route` scope dimension into the REAL RBAC engine.
  # Authorization::Assignment::SCOPE_READERS has had `route: :route_id` since
  # transportation's original (stub) slice, but IdentityAccess::
  # RoleAssignment never had a `scope_route_id` column and
  # PermissionCheck#scope_type_for never checked for it (falls through to
  # :group) — so "a driver sees only their own route" could never exist as a
  # REAL grant, only as a test-only Authorization::StubResolver override
  # (test_helper.rb's with_raw_grants). Confirmed explicitly with the owner:
  # close this now, not defer it — without it, this increment would still
  # leave RBAC "of the word, not of the fact" for the one permission
  # (boarding.manage) the whole :route dimension exists for.
  def change
    create_table :routes, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :driver_staff_member, type: :uuid, index: false,
        foreign_key: { to_table: :staff_members, on_delete: :nullify }
      t.string :name, null: false
      t.string :vehicle_plate
      t.integer :capacity
      t.timestamps
    end
    add_index :routes, %i[institution_id driver_staff_member_id], name: "idx_routes_on_inst_driver"
    enable_rls :routes

    create_table :route_stops, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :route, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.time :scheduled_time
      t.integer :position, null: false
      t.timestamps
    end
    add_index :route_stops, %i[institution_id route_id], name: "idx_route_stops_on_inst_route"
    add_index :route_stops, %i[route_id position], unique: true, name: "idx_route_stops_unique_position"
    enable_rls :route_stops

    create_table :route_riders, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :route, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :route_stop, type: :uuid, index: false,
        foreign_key: { on_delete: :nullify }
      t.string :shift, null: false
      t.timestamps
    end
    add_index :route_riders, %i[institution_id student_id shift],
      unique: true, name: "idx_route_riders_unique_student_shift"
    add_index :route_riders, %i[institution_id route_id], name: "idx_route_riders_on_inst_route"
    add_check_constraint :route_riders, "shift IN ('am','pm')", name: "route_riders_shift_check"
    enable_rls :route_riders

    create_table :boarding_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :route, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :recorded_by_institution_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.string :event_type, null: false
      t.timestamps
    end
    add_index :boarding_events, %i[institution_id route_id], name: "idx_boarding_events_on_inst_route"
    add_check_constraint :boarding_events, "event_type IN ('boarded','alighted')",
      name: "boarding_events_event_type_check"
    enable_rls :boarding_events

    add_column :role_assignments, :scope_route_id, :uuid
    add_foreign_key :role_assignments, :routes, column: :scope_route_id, on_delete: :cascade
    add_index :role_assignments, :scope_route_id

    remove_index :role_assignments, name: "idx_ra_unique_scope"
    add_index :role_assignments,
      %i[institution_id institution_user_id role_id scope_department_id scope_grade_level_id
         scope_group_id scope_route_id],
      unique: true, name: "idx_ra_unique_scope", nulls_not_distinct: true
  end
end
