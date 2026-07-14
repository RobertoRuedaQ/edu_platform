class CreateAcademicStructure < ActiveRecord::Migration[8.1]
  def change
    # University structure: faculties -> programs.
    create_table :faculties, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true  # leading institution_id index
      t.string :name, null: false
      t.string :code, null: false
      t.timestamps
    end
    add_index :faculties, %i[institution_id code], unique: true
    enable_rls :faculties

    create_table :programs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :faculty,     type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :code, null: false
      t.string :degree_level, null: false, default: "pregrado"
      t.timestamps
    end
    add_index :programs, %i[institution_id code], unique: true
    enable_rls :programs

    # School structure: grade_levels -> sections.
    create_table :grade_levels, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.string  :name, null: false
      t.integer :level_number, null: false
      t.timestamps
    end
    add_index :grade_levels, %i[institution_id level_number], unique: true
    enable_rls :grade_levels

    create_table :sections, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution,  type: :uuid, null: false, foreign_key: true
      t.references :grade_level,  type: :uuid, null: true,  foreign_key: true, index: true
      t.string  :name, null: false          # A, B, C ...
      t.integer :academic_year, null: false
      t.timestamps
    end
    enable_rls :sections
  end
end
