class CreateControlPlaneEmailOtps < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL — mirrors email_otps, scoped to platform_admin instead of
    # (institution, user). S0 only ever issues purpose "sign_in".
    create_table :control_plane_email_otps, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :platform_admin, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.string   :code_digest, null: false # digest only, never the raw code
      t.string   :purpose, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.integer  :attempts, null: false, default: 0

      t.timestamps
    end

    add_index :control_plane_email_otps, :platform_admin_id
    add_index :control_plane_email_otps, :expires_at

    add_check_constraint :control_plane_email_otps, "purpose IN ('sign_in')",
      name: "control_plane_email_otps_purpose_check"
  end
end
