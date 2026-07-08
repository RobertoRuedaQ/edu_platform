class CreatePlanPriceTiers < ActiveRecord::Migration[8.1]
  def change
    # Explicit child table (F8), not JSONB — brackets are greppable, queryable
    # rows. Overlap between tiers of the same plan is validated in
    # ControlPlane::Plan (app-level), not the DB.
    #
    # Hardening idea (documented, not built in S1): an
    # int4range(min_students, coalesce(max_students, 2147483647), '[)') column
    # with a GiST exclusion constraint per plan_id would forbid overlap at the
    # DB level too, the same way `schedules` uses WITHOUT OVERLAPS. Deferred —
    # app-level validation is enough for S1's admin-only write path.
    create_table :plan_price_tiers, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :plan, type: :uuid, null: false, index: true,
        foreign_key: { on_delete: :cascade }

      t.integer :min_students, null: false
      t.integer :max_students
      t.bigint  :price_per_student_cents, null: false

      t.timestamps
    end

    add_check_constraint :plan_price_tiers, "min_students >= 0", name: "plan_price_tiers_min_students_check"
    add_check_constraint :plan_price_tiers, "max_students IS NULL OR max_students > min_students",
      name: "plan_price_tiers_max_students_check"
    add_check_constraint :plan_price_tiers, "price_per_student_cents >= 0",
      name: "plan_price_tiers_price_per_student_cents_check"
  end
end
