class AddRoleToPlatformAdmins < ActiveRecord::Migration[8.1]
  def change
    # Default super_admin (== today's de-facto behavior, since every
    # platform_admin currently has full access) — existing/new rows keep
    # working unchanged unless a slice explicitly assigns a narrower role.
    add_column :platform_admins, :role, :string, null: false, default: "super_admin"
    add_check_constraint :platform_admins,
      "role IN ('super_admin', 'billing_ops', 'viewer')", name: "platform_admins_role_check"
  end
end
