class CreateInstitutionUsers < ActiveRecord::Migration[8.1]
  def change
    # TENANT-SCOPED membership: which global user belongs to which institution,
    # and in what role. RLS-enforced.
    create_table :institution_users, id: :uuid, default: -> { "uuidv7()" } do |t|
      # index: false here — the composite unique below is our leading
      # institution_id index (and enforces one membership per user per tenant).
      t.references :institution, type: :uuid, null: false, foreign_key: true, index: false
      t.references :user,        type: :uuid, null: false, foreign_key: true  # user_id index for reverse lookups

      t.string :role, null: false, default: "member"

      t.timestamps
    end

    add_index :institution_users, %i[institution_id user_id], unique: true

    # DB backstop. ENABLE + FORCE + USING/WITH CHECK on institution_id.
    enable_rls :institution_users
  end
end
