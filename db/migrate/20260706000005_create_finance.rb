class CreateFinance < ActiveRecord::Migration[8.1]
  def change
    # Running balance per student. Optimistic lock guards the balance against
    # concurrent updates (lost-update). student_id RESTRICT: protect finances.
    create_table :student_accounts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
                   foreign_key: { to_table: :students, on_delete: :restrict }
      t.decimal :balance, precision: 12, scale: 2, null: false, default: 0
      t.string  :currency, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :student_accounts, %i[institution_id student_id], unique: true
    enable_rls :student_accounts

    create_table :charges, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
                   foreign_key: { to_table: :students, on_delete: :restrict }
      t.string  :invoice_number, null: false     # human-facing business id
      t.string  :description
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string  :currency, null: false
      t.date    :due_on
      t.string  :status, null: false, default: "pending"
      t.string  :idempotency_key
      t.timestamps
    end
    add_index :charges, %i[institution_id invoice_number], unique: true
    add_index :charges, %i[institution_id idempotency_key], unique: true, name: "idx_charges_idempotency"
    add_index :charges, %i[institution_id student_id]
    add_check_constraint :charges, "status IN ('pending','paid','overdue','void')", name: "charges_status_check"
    enable_rls :charges

    # Money-moving op: idempotency_key (anti double-charge) + optimistic lock.
    create_table :payments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student_account, type: :uuid, null: false, index: false,
                   foreign_key: { on_delete: :restrict }
      t.references :charge, type: :uuid, null: true, index: false,
                   foreign_key: { on_delete: :restrict }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string  :currency, null: false
      t.string  :method, null: false
      t.string  :status, null: false, default: "completed"
      t.datetime :paid_at
      t.string  :idempotency_key
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :payments, %i[institution_id idempotency_key], unique: true, name: "idx_payments_idempotency"
    add_index :payments, %i[institution_id student_account_id]
    add_check_constraint :payments, "method IN ('cash','card','transfer','other')", name: "payments_method_check"
    add_check_constraint :payments, "status IN ('pending','completed','failed','void')", name: "payments_status_check"
    enable_rls :payments

    create_table :payment_plans, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
                   foreign_key: { to_table: :students, on_delete: :restrict }
      t.string  :name, null: false
      t.decimal :total_amount, precision: 12, scale: 2, null: false
      t.string  :currency, null: false
      t.string  :status, null: false, default: "active"
      t.timestamps
    end
    add_index :payment_plans, %i[institution_id student_id]
    add_check_constraint :payment_plans, "status IN ('active','completed','cancelled')", name: "payment_plans_status_check"
    enable_rls :payment_plans

    create_table :installments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :payment_plan, type: :uuid, null: false, index: false,
                   foreign_key: { on_delete: :cascade }
      t.integer :sequence, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date    :due_on, null: false
      t.string  :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :installments, %i[institution_id payment_plan_id sequence], unique: true, name: "idx_installments_seq"
    add_check_constraint :installments, "status IN ('pending','paid','overdue')", name: "installments_status_check"
    enable_rls :installments
  end
end
