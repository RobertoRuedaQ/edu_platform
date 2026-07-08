class AddNationalIdToUsers < ActiveRecord::Migration[8.1]
  def change
    # users is a GLOBAL table (no institution_id, no RLS). national_id is
    # encrypted at the app layer (deterministic) so this stores ciphertext;
    # deterministic encryption keeps it stable, which is what lets the unique
    # index below actually enforce uniqueness. Most existing users have none,
    # hence the partial index.
    add_column :users, :national_id, :string

    add_index :users, :national_id, unique: true,
      where: "national_id IS NOT NULL", name: "index_users_on_national_id"
  end
end
