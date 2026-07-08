class CreateGuardianStudents < ActiveRecord::Migration[8.1]
  def change
    # NEW guardian<->student link keyed on a GLOBAL user (guardian_user_id),
    # deliberately separate from the legacy StudentSupport::Guardian /
    # student_guardians tables, which stay untouched.
    create_table :guardian_students, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :guardian_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.string :relationship, null: false
      t.string :status, null: false, default: "active"

      # Accountability actor: keep the link if the creator is removed.
      t.references :created_by, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }

      t.timestamps
    end

    add_index :guardian_students, %i[institution_id guardian_user_id student_id],
      unique: true, name: "index_guardian_students_uniqueness"

    add_check_constraint :guardian_students, "status IN ('active','revoked')",
      name: "guardian_students_status_check"

    enable_rls :guardian_students
  end
end
