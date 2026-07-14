class CreatePlatformAdmins < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL, self-contained platform-admin identity — NOT a Core::User, NOT
    # RLS-scoped, NOT institution_id-owned. Two planes, opposite security
    # rules; see ControlPlane::PlatformAdmin for why this doesn't reuse
    # tenant identity.
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :platform_admins, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "active"
      t.datetime :last_sign_in_at

      t.timestamps
    end

    add_index :platform_admins, :email, unique: true

    add_check_constraint :platform_admins,
      "status IN ('active','suspended')",
      name: "platform_admins_status_check"
  end
end
