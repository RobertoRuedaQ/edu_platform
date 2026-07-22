require "test_helper"

# guidelines/CLOSURE_PLAN.md Fase D: Cafeteria::DietaryRestriction was already
# real (table + model + seed data) — this slice added the ALLERGEN_NAMES/
# BLOCKING_TYPES split and the `blocking` scope that CheckoutsController now
# reads directly, replacing the parallel DietaryRestrictionRoster stub.
class Cafeteria::DietaryRestrictionTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "dr-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_student(institution, code)
    grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
    section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)
    GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: "Est", last_name: code, gender: "female", birthdate: Date.new(2013, 3, 1),
      student_code: code, entry_year: 2023, status: "active")
  end

  test "blocking scope includes only allergy/intolerance types, never dietary preferences" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "DR-1")
      allergy = Cafeteria::DietaryRestriction.create!(institution: institution, student: student,
        restriction_type: "alergia_mani", severity: "severa")
      Cafeteria::DietaryRestriction.create!(institution: institution, student: student,
        restriction_type: "vegetariano", severity: "leve")

      blocking = Cafeteria::DietaryRestriction.where(student_id: student.id).blocking
      assert_equal [ allergy.id ], blocking.pluck(:id)
    end
  end

  test "allergen_name maps the seeded vocabulary to a display name, celiaco and gluten intolerance share one" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "DR-2")
      celiac = Cafeteria::DietaryRestriction.create!(institution: institution, student: student,
        restriction_type: "celiaco", severity: "severa")
      gluten = Cafeteria::DietaryRestriction.create!(institution: institution, student: student,
        restriction_type: "intolerancia_gluten", severity: "moderada")

      assert_equal "Gluten", celiac.allergen_name
      assert_equal "Gluten", gluten.allergen_name
    end
  end

  test "severity_symbol maps the seeded Spanish severities to the English symbols shared/_allergen_flag expects" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "DR-3")
      mild = Cafeteria::DietaryRestriction.create!(institution: institution, student: student,
        restriction_type: "alergia_mani", severity: "leve")
      severe = Cafeteria::DietaryRestriction.create!(institution: institution, student: student,
        restriction_type: "alergia_lactosa", severity: "severa")

      assert_equal :mild, mild.severity_symbol
      assert_equal :severe, severe.severity_symbol
    end
  end
end
