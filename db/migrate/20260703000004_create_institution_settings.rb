class CreateInstitutionSettings < ActiveRecord::Migration[8.1]
  def change
    # TENANT-SCOPED, 1:1 with institution (unique institution_id). This is the
    # row Provisioning::CreateInstitution inserts under SET LOCAL so WITH CHECK
    # passes. RLS-enforced.
    create_table :institution_settings, id: :uuid, default: -> { "uuidv7()" } do |t|
      # unique index on institution_id = the 1:1 constraint AND the leading
      # institution_id index the CI guard requires.
      t.references :institution, type: :uuid, null: false, foreign_key: true, index: { unique: true }

      t.string  :timezone, null: false, default: "UTC"
      t.string  :locale,   null: false, default: "en"
      t.jsonb   :features, null: false, default: {}

      t.timestamps
    end

    enable_rls :institution_settings
  end
end
