module Cafeteria
  # A student's dietary restriction (~5% of students carry one, seeded via
  # db/seeds.rb's RESTRICTIONS/SEVERITIES vocabulary). Real since day one
  # (table + model + seed data) — only `Cafeteria::CheckoutsController` kept
  # reading a parallel STUB (`DietaryRestrictionRoster`) instead of this
  # model (guidelines/CLOSURE_PLAN.md Fase D). This class is the ONLY source
  # of truth for "does this restriction block a purchase" now.
  #
  # ALLERGEN_NAMES / BLOCKING_TYPES split the seeded vocabulary in two:
  # allergies/intolerances (alergia_mani/alergia_lactosa/intolerancia_gluten/
  # celiaco) actually BLOCK a checkout line whose menu item shares the
  # allergen; dietary PREFERENCES (vegetariano/vegano/kosher/halal/diabetico)
  # are informational only, never enforced at checkout — same split the
  # retired stub already documented, now backed by the real table.
  class DietaryRestriction < ApplicationRecord
    self.table_name = "dietary_restrictions"

    ALLERGEN_NAMES = {
      "alergia_mani"        => "Maní",
      "alergia_lactosa"     => "Lactosa",
      "intolerancia_gluten" => "Gluten",
      "celiaco"             => "Gluten"
    }.freeze
    BLOCKING_TYPES = ALLERGEN_NAMES.keys.freeze

    # Seeded severities are Spanish strings ("leve"/"moderada"/"severa"); the
    # shared allergen-flag partial (reused by medical_history AND this
    # checkout block) expects an English symbol. "anafilaxia" isn't in the
    # seed vocabulary today but is mapped defensively in case a real
    # institution records one by hand.
    SEVERITY_SYMBOLS = {
      "leve" => :mild, "moderada" => :moderate, "severa" => :severe, "anafilaxia" => :anaphylaxis
    }.freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student", inverse_of: :dietary_restrictions

    validates :restriction_type, presence: true

    # Only the allergy/intolerance types actually block a purchase.
    scope :blocking, -> { where(restriction_type: BLOCKING_TYPES) }

    def allergen_name = ALLERGEN_NAMES.fetch(restriction_type, restriction_type.humanize)
    def severity_symbol = SEVERITY_SYMBOLS.fetch(severity.to_s, :moderate)
  end
end
