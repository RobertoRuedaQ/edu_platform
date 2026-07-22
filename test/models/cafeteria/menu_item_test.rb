require "test_helper"

# guidelines/CLOSURE_PLAN.md Fase D — cafeteria resto: retires the
# Cafeteria::MenuRoster stub (Data.define, 5 hardcoded rows).
class Cafeteria::MenuItemTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "mi-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "price_amount bridges price_cents (bigint) to a BigDecimal, never Float" do
    institution = build_institution
    within_tenant(institution) do
      item = Cafeteria::MenuItem.create!(institution: institution, name: "Arroz con pollo",
        category: "Almuerzo", price_cents: 950_000)

      assert_instance_of BigDecimal, item.price_amount
      assert_equal BigDecimal("9500"), item.price_amount
    end
  end

  test "allergens must belong to Cafeteria::DietaryRestriction::ALLERGEN_NAMES' vocabulary" do
    institution = build_institution
    within_tenant(institution) do
      item = Cafeteria::MenuItem.new(institution: institution, name: "Torta rara", category: "Snack",
        price_cents: 100_000, allergens: [ "Fresa" ])

      assert_not item.valid?
      assert_includes item.errors[:allergens].join, "Fresa"
    end
  end

  test "category is restricted to the closed vocabulary even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      item = Cafeteria::MenuItem.new(institution: institution, name: "Cena", category: "Cena", price_cents: 100_000)

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { item.save!(validate: false) }
      end
    end
  end

  test "price_cents must be positive even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      item = Cafeteria::MenuItem.new(institution: institution, name: "Gratis", category: "Snack", price_cents: 0)

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { item.save!(validate: false) }
      end
    end
  end
end
