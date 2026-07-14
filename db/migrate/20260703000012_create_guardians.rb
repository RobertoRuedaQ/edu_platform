class CreateGuardians < ActiveRecord::Migration[8.1]
  def change
    # Tutores/acudientes. Both genders. School students may have 2.
    create_table :guardians, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :gender,     null: false        # male | female
      t.string :email
      t.string :phone
      t.string :relationship, null: false, default: "acudiente"  # padre|madre|acudiente
      t.timestamps
    end
    add_check_constraint :guardians, "gender IN ('male','female')", name: "guardians_gender_check"
    enable_rls :guardians

    create_table :student_guardians, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :student,     type: :uuid, null: false, foreign_key: true, index: true
      t.references :guardian,    type: :uuid, null: false, foreign_key: true, index: true
      t.boolean :is_primary, null: false, default: false
      t.timestamps
    end
    add_index :student_guardians, %i[institution_id student_id guardian_id], unique: true
    enable_rls :student_guardians
  end
end
