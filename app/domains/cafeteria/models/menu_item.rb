module Cafeteria
  # Real menu catalog (guidelines/CLOSURE_PLAN.md Fase D — cafeteria resto),
  # replacing `Cafeteria::MenuRoster` (`Data.define`, 5 hardcoded rows).
  # Seeded like `Cafeteria::DietaryRestriction` (db/seeds.rb) — no authoring
  # UI in this increment, same posture already applied to
  # `character_frameworks` (deferred, documented, not an oversight).
  #
  # `allergens` deliberately stores DISPLAY NAMES ("Maní"/"Lactosa"/"Gluten"),
  # not restriction_type codes — this is the exact vocabulary
  # `Cafeteria::DietaryRestriction#allergen_name` produces, so
  # `CheckoutsController#blocked_for_student?` can compare the two directly
  # with no translation layer. `allergens_are_known` keeps the two vocabularies
  # from drifting apart.
  class MenuItem < ApplicationRecord
    self.table_name = "cafeteria_menu_items"

    CATEGORIES = %w[Almuerzo Snack].freeze

    belongs_to :institution, class_name: "Core::Institution"
    has_many :purchase_lines, class_name: "Cafeteria::PurchaseLine", inverse_of: :menu_item,
      dependent: :restrict_with_exception

    validates :name, :category, presence: true
    validates :category, inclusion: { in: CATEGORIES }
    validates :price_cents, numericality: { greater_than: 0 }
    validate :allergens_are_known

    scope :available, -> { where(available: true) }

    def price_amount = BigDecimal(price_cents) / 100

    private

    def allergens_are_known
      known = Cafeteria::DietaryRestriction::ALLERGEN_NAMES.values.uniq
      unknown = Array(allergens) - known
      errors.add(:allergens, "incluye un alérgeno que no existe en el catálogo: #{unknown.join(', ')}") if unknown.any?
    end
  end
end
