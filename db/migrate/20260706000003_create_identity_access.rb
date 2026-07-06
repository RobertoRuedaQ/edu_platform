class CreateIdentityAccess < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL capability catalog (seeded in code). No institution_id -> no RLS,
    # not picked up by the tenant guard. Referenced like institutions/users.
    create_table :permissions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :key, null: false               # students.read, grades.write, …
      t.string :description
      t.timestamps
    end
    add_index :permissions, :key, unique: true

    # Per-tenant roles.
    create_table :roles, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string  :key,  null: false             # admin, area_head, group_director, …
      t.string  :name, null: false
      t.string  :description
      t.boolean :system, null: false, default: false
      t.timestamps
    end
    add_index :roles, %i[institution_id key], unique: true
    enable_rls :roles

    # Role -> capabilities (references the GLOBAL permissions catalog).
    create_table :role_permissions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :role,        type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :permission,  type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :role_permissions, %i[institution_id role_id permission_id], unique: true, name: "idx_rp_unique"
    add_index :role_permissions, %i[institution_id permission_id], name: "idx_rp_inst_permission"
    enable_rls :role_permissions

    # SCOPED assignments: person x role x (optional) scope. All scope columns
    # NULL = institution-wide. Scope FKs CASCADE (never SET NULL: nulling a
    # scope would silently widen the grant to the whole institution).
    create_table :role_assignments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution,      type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :institution_user, type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :role,             type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :scope_department,  type: :uuid, null: true, index: false, foreign_key: { to_table: :departments,  on_delete: :cascade }
      t.references :scope_grade_level, type: :uuid, null: true, index: false, foreign_key: { to_table: :grade_levels, on_delete: :cascade }
      t.references :scope_group,       type: :uuid, null: true, index: false, foreign_key: { to_table: :sections,     on_delete: :cascade }
      t.string :idempotency_key
      t.timestamps
    end
    # One assignment per (person, role, exact scope). NULLS NOT DISTINCT so two
    # institution-wide (all-NULL) duplicates are actually rejected.
    add_index :role_assignments,
      %i[institution_id institution_user_id role_id scope_department_id scope_grade_level_id scope_group_id],
      unique: true, nulls_not_distinct: true, name: "idx_ra_unique_scope"
    add_index :role_assignments, %i[institution_id idempotency_key], unique: true, name: "idx_ra_idempotency"
    add_index :role_assignments, %i[institution_id institution_user_id], name: "idx_ra_inst_user"
    add_index :role_assignments, %i[institution_id role_id], name: "idx_ra_inst_role"
    enable_rls :role_assignments
  end
end
