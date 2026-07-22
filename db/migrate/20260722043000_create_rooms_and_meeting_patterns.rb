class CreateRoomsAndMeetingPatterns < ActiveRecord::Migration[8.1]
  # guidelines/CLOSURE_PLAN.md Fase D (fourth increment): retires `schedules`'
  # timetable/rooms half from 100% stub (`RoomRoster`/`ScheduleEventRoster`,
  # `Data.define` hardcoded rows) — the other dead end this session's recon
  # flagged alongside `transportation` (v1.49.0): real nav ("Horario
  # institucional"), real controllers/routes, fake data underneath.
  #
  # Two decisions confirmed by the owner before migrating:
  #
  # 1) FLAT meeting_pattern, no shared "periods" grid — the stub's own data
  #    never assumed an institution-wide bell schedule (different subjects
  #    freely use different day/time combinations); a `periods` table would
  #    have been a rigid abstraction nothing in the current data asks for.
  #    `meeting_patterns` carries its own `day_of_week` + `starts_at`/
  #    `ends_at` directly.
  #
  # 2) Room double-booking is PERMITTED, never blocked at the DB level — the
  #    retired stub was explicit ("REFLECTS a conflict flag, never computes
  #    one") and its own sample data had two meeting patterns sharing a room
  #    marked as a conflict, not rejected. No EXCLUDE gist here (unlike
  #    classroom_layouts/seat_assignments, v1.36.0) — a real schedule
  #    exception needs to be representable; conflict is COMPUTED at read
  #    time instead (Schedules::MeetingPatternPresenter), covering both room
  #    overlap and section overlap (a group physically can't be in two
  #    classes at once — a natural extension of "compute at read time",
  #    not a new business rule).
  def change
    create_table :rooms, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :kind, null: false, default: "classroom"
      t.integer :capacity
      t.string :building
      t.timestamps
    end
    add_index :rooms, %i[institution_id name], unique: true, name: "idx_rooms_unique_name_per_institution"
    add_check_constraint :rooms, "kind IN ('classroom','lab','other')", name: "rooms_kind_check"
    enable_rls :rooms

    create_table :meeting_patterns, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :subject, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :subjects, on_delete: :cascade }
      t.references :section, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :room, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :restrict }
      t.string :day_of_week, null: false
      t.time :starts_at, null: false
      t.time :ends_at, null: false
      t.timestamps
    end
    add_index :meeting_patterns, %i[institution_id section_id], name: "idx_meeting_patterns_on_inst_section"
    add_index :meeting_patterns, %i[institution_id room_id], name: "idx_meeting_patterns_on_inst_room"
    add_check_constraint :meeting_patterns, "day_of_week IN ('mon','tue','wed','thu','fri')",
      name: "meeting_patterns_day_check"
    add_check_constraint :meeting_patterns, "ends_at > starts_at", name: "meeting_patterns_time_range_check"
    enable_rls :meeting_patterns
  end
end
