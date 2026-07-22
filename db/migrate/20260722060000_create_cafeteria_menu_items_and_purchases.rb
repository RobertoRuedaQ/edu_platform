class CreateCafeteriaMenuItemsAndPurchases < ActiveRecord::Migration[8.1]
  # guidelines/CLOSURE_PLAN.md Fase D — cafeteria resto (Menú/Compra/Saldo,
  # v1.47.0 left this deferred on purpose): retires the two remaining stubs
  # (`MenuRoster`/`StudentAccountRoster`, both `Data.define`) and makes a real
  # sale persist for the first time — `CheckoutsController#create` today only
  # flashes "Compra registrada (stub)" and writes nothing.
  #
  # Decisions (recommended/conservative default, no new business rule
  # confirmed by the owner — same posture as every other Fase D increment):
  #
  # 1) NO separate cafeteria wallet. `finance.student_accounts` is already the
  #    ONE shared balance the whole app charges into — `Extracurriculars::
  #    EnrollmentCreator#charge_for_paid_activity` established this precedent
  #    for a different paid-good domain (find_or_create the account, then
  #    Finance::ChargeCreator). Both cafeteria portal stubs' own TODOs name a
  #    hypothetical `Cafeteria::StudentAccount` that never existed and
  #    contradicts this precedent — corrected here, not built.
  # 2) A purchase is a `Finance::Charge` (amount OWED increases), never a
  #    prepaid-credit deduction — there is no top-up/"Recarga" flow anywhere
  #    in the app, so "balance" here means accounts-receivable, exactly like
  #    tuition and extracurricular fees.
  # 3) Money is NEW in this domain -> `*_cents bigint` (F6), never `decimal`
  #    (that convention is grandfathered to `finance`'s five original
  #    tables only). `Cafeteria::MenuItem#price_amount`/`Purchase#
  #    total_price_amount` are the one bridge cents -> BigDecimal/100 each,
  #    molde `Extracurriculars::Activity#fee_amount`.
  # 4) No menu-authoring UI in this increment — same posture already applied
  #    to `character_frameworks` authorship (Slice 6, deferred, documented,
  #    not an oversight). `cafeteria_menu_items` is seeded like
  #    `dietary_restrictions` already is; nothing today signals an
  #    institution needs to curate its own menu.
  # 5) `cafeteria_purchase_lines` snapshots `item_name`/`unit_price_cents` at
  #    sale time (molde `lines_snapshot`/`framework_snapshot`) — a later
  #    price or name change on the menu item must never rewrite history.
  def change
    create_table :cafeteria_menu_items, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string  :name, null: false
      t.string  :category, null: false
      t.bigint  :price_cents, null: false
      t.string  :allergens, array: true, null: false, default: []
      t.string  :dietary_tags, array: true, null: false, default: []
      t.boolean :available, null: false, default: true
      t.timestamps
    end
    add_index :cafeteria_menu_items, %i[institution_id available]
    add_check_constraint :cafeteria_menu_items, "category IN ('Almuerzo','Snack')",
      name: "cafeteria_menu_items_category_check"
    add_check_constraint :cafeteria_menu_items, "price_cents > 0",
      name: "cafeteria_menu_items_price_check"
    enable_rls :cafeteria_menu_items

    create_table :cafeteria_purchases, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :restrict }
      t.references :recorded_by_institution_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.references :charge, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :charges, on_delete: :restrict }
      t.bigint   :total_price_cents, null: false
      t.string   :idempotency_key
      t.datetime :purchased_at, null: false
      t.timestamps
    end
    add_index :cafeteria_purchases, %i[institution_id student_id]
    add_index :cafeteria_purchases, %i[institution_id charge_id]
    add_index :cafeteria_purchases, %i[institution_id idempotency_key], unique: true,
      name: "idx_cafeteria_purchases_idempotency"
    add_check_constraint :cafeteria_purchases, "total_price_cents > 0",
      name: "cafeteria_purchases_total_check"
    enable_rls :cafeteria_purchases

    create_table :cafeteria_purchase_lines, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :purchase, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :cafeteria_purchases, on_delete: :cascade }
      t.references :menu_item, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :cafeteria_menu_items, on_delete: :restrict }
      t.string :item_name, null: false
      t.bigint :unit_price_cents, null: false
      t.timestamps
    end
    add_index :cafeteria_purchase_lines, %i[institution_id purchase_id]
    add_check_constraint :cafeteria_purchase_lines, "unit_price_cents > 0",
      name: "cafeteria_purchase_lines_price_check"
    enable_rls :cafeteria_purchase_lines
  end
end
