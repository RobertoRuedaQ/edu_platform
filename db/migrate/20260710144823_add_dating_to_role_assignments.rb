class AddDatingToRoleAssignments < ActiveRecord::Migration[8.1]
  def change
    # R5 (P1): a grant is effective only within [valid_from, valid_until].
    # valid_until nil == open-ended (the common case). Existing rows default
    # to today so nothing already granted silently loses access on deploy.
    add_column :role_assignments, :valid_from, :date, null: false, default: -> { "CURRENT_DATE" }
    add_column :role_assignments, :valid_until, :date

    add_check_constraint :role_assignments,
      "valid_until IS NULL OR valid_until >= valid_from",
      name: "role_assignments_valid_until_after_valid_from"
  end
end
