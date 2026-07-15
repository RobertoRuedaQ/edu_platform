class CreateReportCards < ActiveRecord::Migration[8.1]
  # report_cards (net-new domain, v1.17.0, item #3 of the MVP critical path).
  # Frozen at publish time — a published row's lines_snapshot/overall_average
  # are computed ONCE by ReportCards::Publisher and never re-read from live
  # Schedules::Assessment data again (hard invariant, see HISTORIA.md
  # v1.17.0). Default decision: "draft" is a live computation with NO row —
  # a report_cards row exists only once published, so `status` is always
  # "published" for any persisted row today; the CHECK still allows "draft"
  # only in case that decision reverses later (kept honest with the design
  # doc rather than dropped as unreachable).
  def change
    create_table :report_cards, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: true,
        foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: "published"
      # Per-subject frozen lines: [{subject_id, subject_name, average}, ...].
      t.jsonb  :lines_snapshot, null: false, default: []
      t.decimal :overall_average, precision: 3, scale: 1
      t.datetime :published_at, null: false
      # Nullable for the same reason attendance_records.recorded_by_staff_member
      # is: not every actor holds a StaffManagement::StaffMember row (D1's
      # additive transition is still partial) — publishing without one is a
      # normal state, never blocked.
      t.references :published_by_staff_member, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :staff_members, on_delete: :nullify }

      t.timestamps
    end

    add_index :report_cards, %i[institution_id student_id academic_term_id], unique: true,
      name: "index_report_cards_on_institution_student_term"
    add_index :report_cards, %i[institution_id academic_term_id],
      name: "index_report_cards_on_institution_term"

    add_check_constraint :report_cards,
      "status IN ('draft','published')",
      name: "report_cards_status_check"

    enable_rls :report_cards
  end
end
