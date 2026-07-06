class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true  # leading institution_id index

      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :gender,     null: false        # male | female
      t.date   :birthdate,  null: false
      t.string :student_code, null: false      # human-facing business id, per-tenant
      t.string :email
      t.string :status, null: false, default: "active"

      # Transportation: everyone lives in the same city (Bogotá) for this seed.
      t.string :city,    null: false, default: "Bogotá"
      t.string :address

      t.integer :entry_year, null: false

      # School placement (nullable for university students) ...
      t.references :grade_level, type: :uuid, null: true, foreign_key: true, index: true
      t.references :section,     type: :uuid, null: true, foreign_key: true, index: true
      # ... university placement (nullable for school students).
      t.references :program,     type: :uuid, null: true, foreign_key: true, index: true

      t.timestamps
    end

    add_index :students, %i[institution_id student_code], unique: true
    add_check_constraint :students, "gender IN ('male','female')", name: "students_gender_check"
    enable_rls :students
  end
end
