class CreateStaffManagement < ActiveRecord::Migration[8.1]
  def change
    # Areas/departments. Owned by staff_management; identity_access references
    # these via role_assignments.scope_department_id.
    create_table :departments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false,
                   foreign_key: { on_delete: :cascade }  # tenant teardown; leading institution_id index
      t.string :name, null: false
      t.string :code, null: false
      t.string :kind, null: false                        # academic | operational
      t.timestamps
    end
    add_index :departments, %i[institution_id code], unique: true
    add_check_constraint :departments, "kind IN ('academic','operational')", name: "departments_kind_check"
    enable_rls :departments

    # Employment backbone for ALL staff (teaching and non-teaching).
    create_table :staff_members, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false,
                   foreign_key: { on_delete: :cascade }
      t.references :institution_user, type: :uuid, null: false,
                   foreign_key: { on_delete: :cascade }  # employment tied to membership
      t.references :department, type: :uuid, null: true, index: false,
                   foreign_key: { on_delete: :nullify }  # dept removed -> unassigned
      t.string :employee_number, null: false             # human-facing business id
      t.string :staff_category,  null: false             # teaching|kitchen|transport|maintenance|security|admin|other
      t.string :employment_type, null: false             # full_time|part_time|contract
      t.date   :hire_date
      t.string :status, null: false, default: "active"   # active|on_leave|terminated
      t.timestamps
    end
    add_index :staff_members, %i[institution_id institution_user_id], unique: true
    add_index :staff_members, %i[institution_id employee_number],     unique: true
    add_index :staff_members, %i[institution_id department_id]
    add_check_constraint :staff_members,
      "staff_category IN ('teaching','kitchen','transport','maintenance','security','admin','other')",
      name: "staff_members_category_check"
    add_check_constraint :staff_members,
      "employment_type IN ('full_time','part_time','contract')",
      name: "staff_members_employment_type_check"
    add_check_constraint :staff_members,
      "status IN ('active','on_leave','terminated')",
      name: "staff_members_status_check"
    enable_rls :staff_members

    # Optional HR depth: contracts / employment spells.
    create_table :employment_periods, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false,
                   foreign_key: { on_delete: :cascade }
      t.references :staff_member, type: :uuid, null: false, index: false,
                   foreign_key: { on_delete: :cascade }
      t.string  :contract_type, null: false
      t.date    :starts_on, null: false
      t.date    :ends_on
      t.decimal :fte, precision: 4, scale: 2
      t.string  :status, null: false, default: "active"  # active|ended
      t.timestamps
    end
    add_index :employment_periods, %i[institution_id staff_member_id]
    add_check_constraint :employment_periods, "status IN ('active','ended')", name: "employment_periods_status_check"
    enable_rls :employment_periods
  end
end
