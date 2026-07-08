class AddNationalIdToStudents < ActiveRecord::Migration[8.1]
  def change
    # Tenant-scoped. Encrypted deterministically at the app layer; the partial
    # unique index is scoped by institution so the same national_id may exist
    # in different tenants but never twice within one.
    add_column :students, :national_id, :string

    add_index :students, %i[institution_id national_id], unique: true,
      where: "national_id IS NOT NULL",
      name: "index_students_on_institution_and_national_id"
  end
end
