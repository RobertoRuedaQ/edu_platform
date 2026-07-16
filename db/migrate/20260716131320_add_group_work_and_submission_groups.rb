class AddGroupWorkAndSubmissionGroups < ActiveRecord::Migration[8.1]
  # assignments (v1.23.0, item #6 of the MVP critical path: group work).
  # Generalizes v1.22.0's Submission (per-student) to belong to a student
  # XOR a submission group — same num_nonnulls CHECK pattern
  # conversation_participants (v1.20.0) already established for "identity
  # A or identity B, never neither/both". Publisher's per-student fan-out
  # (v1.21.0) is UNCHANGED: every roster student still gets their own
  # schedules::Assessment row regardless of group_work — a group grade is
  # just a bulk-set over those same rows (Assignments::GroupGrader), never
  # a second grade store. No collision with GroupManagement::Section (the
  # "class group" concept) — this is a per-assignment work group, a
  # completely separate namespace (Assignments::SubmissionGroup).
  def change
    add_column :assignments, :group_work, :boolean, null: false, default: false

    create_table :submission_groups, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :assignment, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :assignments, on_delete: :cascade }
      t.string :name, null: false

      t.timestamps
    end
    add_index :submission_groups, %i[institution_id assignment_id], name: "idx_submission_groups_on_institution_assignment"
    enable_rls :submission_groups

    # Groups are per-TASK, never reusable across assignments (§0) — the
    # unique index is scoped by assignment_id, not a standalone roster.
    create_table :group_memberships, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :submission_group, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :submission_groups, on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      # Denormalized for the unique below — a student's group changes
      # per-assignment, so "which assignment is this membership for" must
      # be queryable without an extra join through submission_group.
      t.references :assignment, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :assignments, on_delete: :cascade }

      t.timestamps
    end
    add_index :group_memberships, %i[institution_id assignment_id student_id], unique: true,
      name: "idx_group_memberships_unique_student_per_assignment"
    add_index :group_memberships, %i[institution_id submission_group_id], name: "idx_group_memberships_on_group"
    enable_rls :group_memberships

    # Generalize submissions (v1.22.0): student_id becomes optional, gains
    # submission_group_id as the other half of the XOR. Existing per-student
    # rows already satisfy the CHECK untouched (student_id set, group nil).
    change_column_null :submissions, :student_id, true
    add_reference :submissions, :submission_group, type: :uuid, null: true, index: false,
      foreign_key: { on_delete: :cascade }
    add_index :submissions, %i[institution_id assignment_id submission_group_id], unique: true,
      name: "idx_submissions_unique_assignment_group"
    add_check_constraint :submissions, "num_nonnulls(student_id, submission_group_id) = 1",
      name: "submissions_identity_check"
  end
end
