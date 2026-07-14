class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL catalog — same posture as addons (no RLS, no institution_id).
    # F9: plans and addons are independent catalogs in S1, no FK between them.
    create_table :plans, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text   :description

      # Applies when no plan_price_tiers row covers a given headcount (S4
      # resolves this; S1 only stores the data — see PlanPriceTier).
      t.bigint :base_price_per_student_cents, null: false
      t.string :currency, null: false, default: "COP"

      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :plans, :key, unique: true

    add_check_constraint :plans, "char_length(currency) = 3", name: "plans_currency_check"
    add_check_constraint :plans, "status IN ('active','retired')", name: "plans_status_check"
    add_check_constraint :plans, "base_price_per_student_cents >= 0",
      name: "plans_base_price_per_student_cents_check"
  end
end
