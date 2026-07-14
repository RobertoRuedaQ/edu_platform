class CreateCounseling < ActiveRecord::Migration[8.1]
  # Sensitive domain. Tenant RLS is the baseline here; a stricter, role-aware
  # predicate (counseling.read) is documented for the auth iteration — see the
  # domain README. Authorship FKs are RESTRICT to preserve accountability.
  def change
    create_table :counseling_cases, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
                   foreign_key: { to_table: :students, on_delete: :restrict }
      t.references :opened_by, type: :uuid, null: false,
                   foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.string :category, null: false
      t.string :status, null: false, default: "open"
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.timestamps
    end
    add_index :counseling_cases, %i[institution_id student_id]
    add_check_constraint :counseling_cases, "status IN ('open','in_progress','closed')", name: "counseling_cases_status_check"
    enable_rls :counseling_cases

    create_table :session_notes, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :counseling_case, type: :uuid, null: false, index: false,
                   foreign_key: { on_delete: :cascade }
      t.references :author, type: :uuid, null: false,
                   foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.datetime :occurred_at, null: false
      t.text    :body, null: false
      t.boolean :confidential, null: false, default: true
      t.timestamps
    end
    add_index :session_notes, %i[institution_id counseling_case_id]
    enable_rls :session_notes

    create_table :referrals, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :counseling_case, type: :uuid, null: false, index: false,
                   foreign_key: { on_delete: :cascade }
      t.string :referred_to, null: false
      t.text   :reason
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :referrals, %i[institution_id counseling_case_id]
    add_check_constraint :referrals, "status IN ('pending','accepted','completed','declined')", name: "referrals_status_check"
    enable_rls :referrals
  end
end
