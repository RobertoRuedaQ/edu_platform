class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    # citext is trusted contrib (no superuser needed) — case-insensitive email
    # uniqueness without a functional index. Reversible via disable_extension.
    enable_extension "citext" unless extension_enabled?("citext")

    # GLOBAL table — a user can belong to many institutions, so identity lives
    # outside any tenant. No institution_id, no RLS. Membership is separate.
    create_table :users, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.citext :email, null: false
      t.string :name,  null: false, default: ""
      t.string :password_digest        # has_secure_password contract

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
