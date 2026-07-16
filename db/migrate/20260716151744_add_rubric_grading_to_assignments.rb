class AddRubricGradingToAssignments < ActiveRecord::Migration[8.1]
  # assignments (v1.26.0, slice 4: rúbricas — closes the assignments track).
  # evaluation_method is a per-task toggle, same freeze discipline as
  # group_work (v1.23.0): settable while draft, locked once published (see
  # Assignment#lock_evaluation_method_after_publish). rubric_template_id is
  # PROVENANCE ONLY once published — same role as ControlPlane::
  # Subscription#plan_id: it names which template was chosen, but
  # rubric_snapshot (frozen at publish, see Assignments::Publisher) is the
  # only thing ever read for grading/rendering afterward. Editing or even
  # deleting the live template later never touches a published assignment.
  def change
    add_column :assignments, :evaluation_method, :string, null: false, default: "direct"
    add_check_constraint :assignments, "evaluation_method IN ('direct', 'rubric')",
      name: "assignments_evaluation_method_check"
    add_reference :assignments, :rubric_template, type: :uuid, null: true, index: false,
      foreign_key: { on_delete: :nullify }
    add_column :assignments, :rubric_snapshot, :jsonb

    # The evaluation itself (which level got marked per criterion) is
    # domain DATA, never the grade — schedules::Assessment stays the only
    # place a score lives (Assignments::RubricGrader/GroupRubricGrader
    # write there, same as GradeRecorder/GroupGrader always have). Same
    # student XOR submission_group CHECK as submissions (v1.23.0) — an
    # evaluation belongs to exactly one of the two, mirroring who the
    # underlying entrega belongs to.
    create_table :rubric_evaluations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :assignment, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :submission_group, type: :uuid, null: true, index: false,
        foreign_key: { on_delete: :cascade }
      # criterion_snapshot_id => level_snapshot_id — keyed against
      # assignment.rubric_snapshot's frozen ids, never the live
      # rubric_criteria/rubric_levels rows (which may later change or be
      # destroyed without affecting an already-graded assignment).
      t.jsonb :levels_by_criterion, null: false, default: {}
      t.references :evaluated_by_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end
    add_index :rubric_evaluations, %i[institution_id assignment_id student_id], unique: true,
      name: "idx_rubric_evaluations_unique_student"
    add_index :rubric_evaluations, %i[institution_id assignment_id submission_group_id], unique: true,
      name: "idx_rubric_evaluations_unique_group"
    enable_rls :rubric_evaluations
    add_check_constraint :rubric_evaluations, "num_nonnulls(student_id, submission_group_id) = 1",
      name: "rubric_evaluations_identity_check"
  end
end
