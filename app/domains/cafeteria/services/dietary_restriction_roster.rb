module Cafeteria
  # STUB, but shaped exactly like the REAL (seeded, RLS-backed)
  # Cafeteria::DietaryRestriction — restriction_type uses the same vocabulary
  # as db/seeds.rb's RESTRICTIONS list. Only the allergy/intolerance types
  # block a purchase; dietary preferences (vegetariano, vegano, kosher, halal,
  # diabetico) are informational only, never enforced here.
  #
  # TODO: reemplazar por Cafeteria::DietaryRestriction real (ya existe la
  # tabla y el modelo, solo falta contexto de tenant resuelto por request).
  module DietaryRestrictionRoster
    ALLERGEN_NAMES = {
      "alergia_mani"        => "Maní",
      "alergia_lactosa"     => "Lactosa",
      "intolerancia_gluten" => "Gluten",
      "celiaco"             => "Gluten"
    }.freeze

    Row = Data.define(:student_id, :restriction_type, :severity, :allergen_name)

    def self.all
      [
        Row.new(student_id: "s-1", restriction_type: "alergia_mani", severity: "severa",
                allergen_name: ALLERGEN_NAMES["alergia_mani"]),
        Row.new(student_id: "s-5", restriction_type: "alergia_lactosa", severity: "moderada",
                allergen_name: ALLERGEN_NAMES["alergia_lactosa"]),
        Row.new(student_id: "s-8", restriction_type: "celiaco", severity: "severa",
                allergen_name: ALLERGEN_NAMES["celiaco"])
      ]
    end

    def self.for_student(student_id)
      all.select { |row| row.student_id == student_id.to_s }
    end

    def self.blocking_allergen_names(student_id)
      for_student(student_id).map(&:allergen_name)
    end
  end
end
