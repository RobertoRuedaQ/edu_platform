class CreateDietaryRestrictions < ActiveRecord::Migration[8.1]
  def change
    # Cafetería: ~5% of students carry a dietary restriction.
    create_table :dietary_restrictions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: true
      t.references :student,     type: :uuid, null: false, foreign_key: true, index: true
      t.string :restriction_type, null: false  # vegetariano|vegano|celiaco|alergia_mani|...
      t.string :severity                        # leve|moderada|severa
      t.text   :notes
      t.timestamps
    end
    enable_rls :dietary_restrictions
  end
end
