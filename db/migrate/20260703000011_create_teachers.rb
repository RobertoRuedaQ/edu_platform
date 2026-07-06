class CreateTeachers < ActiveRecord::Migration[8.1]
  def change
    create_table :teachers, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :faculty,     type: :uuid, null: true,  foreign_key: true, index: true  # university
      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :gender,     null: false        # male | female — both represented
      t.string :email
      t.string :teacher_code, null: false
      t.date   :hired_on
      t.timestamps
    end
    add_index :teachers, %i[institution_id teacher_code], unique: true
    add_check_constraint :teachers, "gender IN ('male','female')", name: "teachers_gender_check"
    enable_rls :teachers

    # Which teacher teaches which subject.
    create_table :teaching_assignments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :teacher,     type: :uuid, null: false, foreign_key: true, index: true
      t.references :subject,     type: :uuid, null: false, foreign_key: true, index: true
      t.timestamps
    end
    add_index :teaching_assignments, %i[institution_id teacher_id subject_id], unique: true
    enable_rls :teaching_assignments
  end
end
