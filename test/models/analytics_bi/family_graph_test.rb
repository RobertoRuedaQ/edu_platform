require "test_helper"

# Slice 8 (BI_DOCUMENT.md §5.6, §6.2): GuardianRelationship/Household models,
# sibling detection (AnalyticsBi::Lens::FamilyCoreScope, no new table — reuses
# core.guardian_students), and the orbital graph assembly
# (AnalyticsBi::Lens::FamilyGraph). The hard invariant this file proves:
# custody_kind NEVER reaches the graph payload, even though it is a real,
# populated column on the underlying model.
class AnalyticsBi::FamilyGraphTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "fg-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_grade_and_section(institution)
    grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
    section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)
    [ grade, section ]
  end

  def build_student(institution, grade, section, first, code)
    GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: first, last_name: "Perez", gender: "female", birthdate: Date.new(2013, 1, 1),
      student_code: code, entry_year: 2023, status: "active")
  end

  def build_guardian(email_prefix)
    Core::User.create!(email: "#{email_prefix}-#{SecureRandom.hex(4)}@test", name: "Acudiente #{email_prefix}",
      password: "password-123456")
  end

  test "a closed relationship_kind is enforced by the DB CHECK" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      student = build_student(institution, grade, section, "Ana", "FG-ANA")
      guardian = build_guardian("g1")
      gs = Core::GuardianStudent.create!(institution: institution, guardian: guardian, student: student,
        relationship: "madre", status: "active")

      relationship = AnalyticsBi::GuardianRelationship.new(institution: institution, guardian_student: gs,
        relationship_kind: "invented")
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { relationship.save!(validate: false) }
      end
    end
  end

  test "a guardian_relationship is unique per guardian_student — one extension row per link" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      student = build_student(institution, grade, section, "Ana", "FG-ANA2")
      guardian = build_guardian("g2")
      gs = Core::GuardianStudent.create!(institution: institution, guardian: guardian, student: student,
        relationship: "madre", status: "active")
      AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs, relationship_kind: "mother")

      assert_raises(ActiveRecord::RecordInvalid) do
        AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs, relationship_kind: "mother")
      end
    end
  end

  test "siblings are detected via a SHARED PRIMARY caregiver, never via any shared guardian" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      ana = build_student(institution, grade, section, "Ana", "FG-ANA3")
      leo = build_student(institution, grade, section, "Leo", "FG-LEO3")
      mom = build_guardian("mom")
      teacher_as_guardian_role = build_guardian("aunt") # a non-primary guardian shared by neither

      gs_ana_mom = Core::GuardianStudent.create!(institution: institution, guardian: mom, student: ana, relationship: "madre", status: "active")
      gs_leo_mom = Core::GuardianStudent.create!(institution: institution, guardian: mom, student: leo, relationship: "madre", status: "active")
      AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs_ana_mom,
        relationship_kind: "mother", is_primary_caregiver: true)
      AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs_leo_mom,
        relationship_kind: "mother", is_primary_caregiver: true)

      siblings = AnalyticsBi::Lens::FamilyCoreScope.new(institution: institution).siblings_for(ana)
      assert_equal [ leo.id ], siblings.pluck(:id)
    end
  end

  test "a shared guardian who is NOT marked primary caregiver yields no detected siblings — honest empty state" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      ana = build_student(institution, grade, section, "Ana", "FG-ANA4")
      leo = build_student(institution, grade, section, "Leo", "FG-LEO4")
      mom = build_guardian("mom4")

      Core::GuardianStudent.create!(institution: institution, guardian: mom, student: ana, relationship: "madre", status: "active")
      Core::GuardianStudent.create!(institution: institution, guardian: mom, student: leo, relationship: "madre", status: "active")
      # NO AnalyticsBi::GuardianRelationship created — no primary caregiver marked yet.

      assert_empty AnalyticsBi::Lens::FamilyCoreScope.new(institution: institution).siblings_for(ana)
    end
  end

  test "the orbital graph centers the student, includes guardians+siblings+edges, and NEVER exposes custody_kind" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      ana = build_student(institution, grade, section, "Ana", "FG-ANA5")
      leo = build_student(institution, grade, section, "Leo", "FG-LEO5")
      mom = build_guardian("mom5")

      gs_ana = Core::GuardianStudent.create!(institution: institution, guardian: mom, student: ana, relationship: "madre", status: "active")
      gs_leo = Core::GuardianStudent.create!(institution: institution, guardian: mom, student: leo, relationship: "madre", status: "active")
      AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs_ana,
        relationship_kind: "mother", is_primary_caregiver: true, custody_kind: "sole")
      AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs_leo,
        relationship_kind: "mother", is_primary_caregiver: true)

      graph = AnalyticsBi::Lens::FamilyGraph.for(student: ana, institution: institution)
      assert graph.any?
      assert_equal 1, graph.guardians.size
      assert_equal [ "Leo Perez" ], graph.siblings.map(&:name)

      elements = graph.cytoscape_elements
      assert_equal 5, elements.size # center + 1 guardian + 1 sibling + 2 edges
      assert elements.any? { |e| e[:data][:type] == "student" && e[:data][:id] == "center" }

      # Structural proof (§6.2): custody_kind is a real, populated value on the
      # underlying model, yet appears NOWHERE in the graph's serialized payload.
      payload = elements.to_json
      assert_no_match(/sole/, payload, "custody_kind must never reach the graph payload")
      assert_no_match(/custody/i, payload, "no custody-related key belongs in the graph payload")
    end
  end

  test "an empty graph (no guardian metadata yet) is honest — never a fake node" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      ana = build_student(institution, grade, section, "Ana", "FG-ANA6")

      graph = AnalyticsBi::Lens::FamilyGraph.for(student: ana, institution: institution)
      refute graph.any?
      assert_empty graph.guardians
      assert_empty graph.siblings
    end
  end
end
