class CreateAcademics < ActiveRecord::Migration[8.1]
  def change
    # Subjects: attached to a grade_level (school) or a program (university).
    create_table :subjects, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :grade_level, type: :uuid, null: true,  foreign_key: true, index: true
      t.references :program,     type: :uuid, null: true,  foreign_key: true, index: true
      t.string  :name, null: false
      t.string  :code, null: false
      t.integer :credits
      t.string  :term, null: false            # e.g. "2026-1"
      t.timestamps
    end
    add_index :subjects, %i[institution_id code term], unique: true
    enable_rls :subjects

    # Enrollment: a student takes a subject in a term.
    create_table :enrollments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :student,     type: :uuid, null: false, foreign_key: true, index: true
      t.references :subject,     type: :uuid, null: false, foreign_key: true, index: true
      t.string :term,   null: false
      t.string :status, null: false, default: "enrolled"
      t.timestamps
    end
    add_index :enrollments, %i[institution_id student_id subject_id], unique: true
    enable_rls :enrollments

    # Assessments: the grades. "notas de diferente índole" — quiz, taller,
    # parcial, proyecto, participación. score on the 0.0–5.0 scale (pass 3.0).
    create_table :assessments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :enrollment,  type: :uuid, null: false, foreign_key: true, index: true
      t.string  :kind,  null: false
      t.string  :title, null: false
      t.decimal :score,     precision: 3, scale: 1          # null = pendiente
      t.decimal :max_score, precision: 3, scale: 1, null: false, default: "5.0"
      t.decimal :weight,    precision: 4, scale: 3, null: false, default: "1.0"
      t.date    :assessed_on
      t.string  :term, null: false
      t.timestamps
    end
    add_check_constraint :assessments, "score IS NULL OR (score >= 0 AND score <= 5)",
                         name: "assessments_score_range_check"
    enable_rls :assessments
  end
end
