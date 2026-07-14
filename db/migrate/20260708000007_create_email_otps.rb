class CreateEmailOtps < ActiveRecord::Migration[8.1]
  def change
    create_table :email_otps, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.string   :code_digest, null: false    # digest only, never the raw code
      t.string   :purpose, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.integer  :attempts, null: false, default: 0

      t.timestamps
    end

    add_index :email_otps, %i[institution_id user_id],
      name: "index_email_otps_on_institution_and_user"

    add_check_constraint :email_otps, "purpose IN ('login','step_up')",
      name: "email_otps_purpose_check"

    enable_rls :email_otps
  end
end
