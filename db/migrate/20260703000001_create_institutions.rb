class CreateInstitutions < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL table — it *is* the tenant, so it carries no institution_id and
    # gets no RLS. PG18 native uuidv7() default: time-ordered, index-friendly PKs.
    create_table :institutions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :slug, null: false   # subdomain / tenant-resolution key

      t.timestamps
    end

    add_index :institutions, :slug, unique: true
  end
end
