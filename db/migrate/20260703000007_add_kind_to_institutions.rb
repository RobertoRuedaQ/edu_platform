class AddKindToInstitutions < ActiveRecord::Migration[8.1]
  def up
    add_column :institutions, :kind, :string, null: false, default: "school"
    # New rows must state their kind explicitly; the default only backfills
    # any pre-existing rows (e.g. the demo tenant).
    change_column_default :institutions, :kind, from: "school", to: nil
    add_check_constraint :institutions, "kind IN ('school','university')",
                         name: "institutions_kind_check"
  end

  def down
    remove_check_constraint :institutions, name: "institutions_kind_check"
    remove_column :institutions, :kind
  end
end
