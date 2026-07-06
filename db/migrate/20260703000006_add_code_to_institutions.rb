class AddCodeToInstitutions < ActiveRecord::Migration[8.1]
  def change
    # Human-facing business identifier for the institution (e.g. "SPRINGFIELD-HS"),
    # separate from the uuidv7 PK. Additive migration (immutable-migration hygiene).
    add_column :institutions, :code, :string, null: false
    add_index  :institutions, :code, unique: true
  end
end
