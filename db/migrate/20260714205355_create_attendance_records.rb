class CreateAttendanceRecords < ActiveRecord::Migration[8.1]
  # attendance (net-new domain, v1.16.0, item #2 of the MVP critical path).
  # Daily-by-homeroom only — per-subject attendance is deferred (see
  # HISTORIA.md v1.16.0). One row per (student, date); re-taking the same
  # (group, date) updates these rows via the unique index, never duplicates.
  def change
    create_table :attendance_records, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :students, on_delete: :cascade }
      # "group" here is the homeroom (GroupManagement::Section) attendance was
      # taken for — kept alongside student_id (not derivable from it alone,
      # since a student's CURRENT section_id could differ from the group the
      # attendance was actually recorded against on a past date).
      t.references :group, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :sections, on_delete: :cascade }
      t.date   :date, null: false
      t.string :status, null: false, default: "present"
      # Nullable: not every actor holds a StaffManagement::StaffMember row
      # (D1's additive transition is still partial) — recording attendance
      # without one is a normal state, never blocked.
      t.references :recorded_by_staff_member, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :staff_members, on_delete: :nullify }
      t.text :note

      t.timestamps
    end

    add_index :attendance_records, %i[institution_id student_id date], unique: true,
      name: "index_attendance_records_on_institution_student_date"
    add_index :attendance_records, %i[institution_id group_id date],
      name: "index_attendance_records_on_institution_group_date"

    add_check_constraint :attendance_records,
      "status IN ('present','absent','late','excused')",
      name: "attendance_records_status_check"

    enable_rls :attendance_records
  end
end
