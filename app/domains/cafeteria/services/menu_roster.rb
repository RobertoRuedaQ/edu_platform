module Cafeteria
  # STUB menu — no Menu/MenuItem table exists at all. Allergens deliberately
  # overlap with DietaryRestrictionRoster's vocabulary (Maní/Lactosa/Gluten) so
  # the checkout block is actually exercised, not just decorative.
  #
  # TODO: reemplazar por un modelo real de menú cuando exista.
  module MenuRoster
    Allergen = Data.define(:name, :severity, :reaction)
    Row = Data.define(:id, :name, :category, :price, :dietary_tags, :allergens, :available)

    def self.all
      [
        Row.new(id: "menu-1", name: "Arroz con pollo", category: "Almuerzo", price: 9_500,
                dietary_tags: [], allergens: [], available: true),
        Row.new(id: "menu-2", name: "Sándwich de mantequilla de maní", category: "Snack", price: 4_500,
                dietary_tags: [],
                allergens: [ Allergen.new(name: "Maní", severity: :severe, reaction: "Reacción alérgica severa") ],
                available: true),
        Row.new(id: "menu-3", name: "Yogurt con granola", category: "Snack", price: 3_800,
                dietary_tags: [ "Vegetariano" ],
                allergens: [ Allergen.new(name: "Lactosa", severity: :moderate, reaction: "Malestar digestivo") ],
                available: true),
        Row.new(id: "menu-4", name: "Ensalada vegana", category: "Almuerzo", price: 8_000,
                dietary_tags: %w[Vegano Vegetariano], allergens: [], available: true),
        Row.new(id: "menu-5", name: "Pasta integral", category: "Almuerzo", price: 8_800,
                dietary_tags: [],
                allergens: [ Allergen.new(name: "Gluten", severity: :severe, reaction: "Reacción celíaca") ],
                available: true)
      ]
    end

    def self.find(id)
      all.find { |item| item.id == id.to_s }
    end
  end
end
