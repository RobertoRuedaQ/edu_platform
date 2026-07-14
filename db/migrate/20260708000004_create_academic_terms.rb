class CreateAcademicTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :academic_terms, id: :uuid, default: -> { "uuidv7()" } do |t|
      # index: false — the composite (institution_id, code) below is our leading
      # institution_id index.
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.string :code, null: false            # per-tenant, e.g. "2026-1"
      t.string :name, null: false
      t.date   :starts_on, null: false
      t.date   :ends_on,   null: false
      t.string :status, null: false, default: "upcoming"

      t.timestamps
    end

    add_index :academic_terms, %i[institution_id code], unique: true
    # At most one active term per tenant.
    add_index :academic_terms, :institution_id, unique: true,
      where: "status = 'active'",
      name: "index_academic_terms_one_active_per_institution"

    add_check_constraint :academic_terms,
      "status IN ('upcoming','active','closed')",
      name: "academic_terms_status_check"

    enable_rls :academic_terms
  end
end
