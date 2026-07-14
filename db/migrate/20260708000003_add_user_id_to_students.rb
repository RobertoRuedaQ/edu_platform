class AddUserIdToStudents < ActiveRecord::Migration[8.1]
  def change
    # A student MAY be backed by a global user (login identity). At most one
    # student per user -> partial unique index. on_delete: :nullify mirrors the
    # app-level `has_one :student, dependent: :nullify`: deleting the user must
    # NOT delete the tenant's student record, just detach the identity.
    add_reference :students, :user, type: :uuid, null: true, index: false,
      foreign_key: { on_delete: :nullify }

    add_index :students, :user_id, unique: true,
      where: "user_id IS NOT NULL", name: "index_students_on_user_id"
  end
end
