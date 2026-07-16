class CreateAssignmentMaterials < ActiveRecord::Migration[8.1]
  # assignments (v1.25.0, slice 3b: materiales del docente). Same bridge-
  # table shape as submission_attachments (v1.24.0) — RLS ENABLE+FORCE here
  # is the tenant boundary; Active Storage's own tables stay untouched, no
  # institution_id/RLS added there (see that migration's comment and
  # OPEN_PROCESS.md's guardrail — not reopening that decision). The owner
  # is the Assignment itself, not a Submission: a docente's own resource,
  # not a portal write.
  def change
    create_table :assignment_materials, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :assignment, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      # Attribution only (nullable + nullify, same convention as
      # submission_attachments.attached_by_user_id) — the teacher who
      # uploaded it, never a claim about who owns the assignment.
      t.references :attached_by_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end
    add_index :assignment_materials, %i[institution_id assignment_id],
      name: "idx_assignment_materials_on_institution_assignment"

    enable_rls :assignment_materials
  end
end
