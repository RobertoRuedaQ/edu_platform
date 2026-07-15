class CreateSubmissions < ActiveRecord::Migration[8.1]
  # assignments (v1.22.0, item #6 of the MVP critical path, slice 2/4: text
  # submission). Deliberately NOT anchored to schedules::assessments —
  # submissions is an in-domain key (assignment_id, student_id), keeping
  # `assignments` from coupling to `schedules` for this axis. The pairing
  # between a submission and its grade happens in a read service
  # (Assignments::GradingView), same pattern as Finance::AccountStatement,
  # never via a cross-domain FK. Grading and submitting stay independent
  # axes: grading never requires a submission, submitting never creates a
  # grade.
  def change
    create_table :submissions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :assignment, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :assignments, on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.text :body, null: false
      # Attribution only (nullable + nullify) — a menor sin login (B1)
      # submits THROUGH their guardian; the submission still belongs to the
      # student regardless of who typed it. Never the write's ownership
      # boundary, only a record of who actually entered the text.
      t.references :submitted_by_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :submitted_at, null: false

      t.timestamps
    end

    # One submission per (assignment, student) — last-write-wins, no
    # revision history this slice.
    add_index :submissions, %i[institution_id assignment_id student_id], unique: true,
      name: "idx_submissions_unique_assignment_student"

    enable_rls :submissions
  end
end
