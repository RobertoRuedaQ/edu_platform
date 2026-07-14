class AddDefaultCurrencyToInstitutionSettings < ActiveRecord::Migration[8.1]
  # Finance reads the institution's default currency from here. Additive column
  # only — the table already has RLS + a leading institution_id index.
  def change
    add_column :institution_settings, :default_currency, :string, null: false, default: "COP"
  end
end
