class AddStatusToInstitutionUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :institution_users, :status, :string, null: false, default: "active"

    add_check_constraint :institution_users,
      "status IN ('active','suspended')",
      name: "institution_users_status_check"
  end
end
