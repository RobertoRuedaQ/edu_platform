require "test_helper"

# Slice 7 (BI_DOCUMENT.md §4/§5.5, §1.1.3): the Lens 3 read-model.
# AnalyticsBi::Lens::ConstellationScope resolves WHICH talents the viewer may
# see (institution-wide vs department-scoped specialist, reusing the EXISTING
# :department scope reader — no new scope_type); AnalyticsBi::Lens::
# ConstellationBuilder assembles the graph from that. Exercised directly under
# the tenant GUC (RLS FORCE).
class AnalyticsBi::ConstellationTest < ActiveSupport::TestCase
  FakeContext = Struct.new(:scope) do
    def scope_for(_permission_key) = scope
  end

  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "cs-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_department(institution, name:)
    StaffManagement::Department.create!(institution: institution, name: name, code: name.parameterize.upcase, kind: "academic")
  end

  def institution_wide_context
    FakeContext.new(IdentityAccess::PermissionCheck::Scope::INSTITUTION_WIDE)
  end

  def department_scoped_context(*department_ids)
    FakeContext.new(IdentityAccess::PermissionCheck::Scope.new(
      department_ids: department_ids, grade_level_ids: [], group_ids: [], route_ids: []))
  end

  def build_student(institution, grade, section, code)
    GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: "Est", last_name: code, gender: "female", birthdate: Date.new(2013, 3, 1),
      student_code: code, entry_year: 2023, status: "active")
  end

  test "an institution-wide grant sees every active talent in the institution" do
    institution = build_institution
    within_tenant(institution) do
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Fútbol", kind: "sport")
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Piano", kind: "art")

      resolved = AnalyticsBi::Lens::ConstellationScope.new(context: institution_wide_context, institution: institution).resolve
      assert_equal 2, resolved.count
    end
  end

  test "a department-scoped specialist sees ONLY their department's talents" do
    institution = build_institution
    within_tenant(institution) do
      sports = build_department(institution, name: "Deportes")
      arts = build_department(institution, name: "Artes")
      futbol = AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Fútbol", kind: "sport", department: sports)
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Piano", kind: "art", department: arts)

      resolved = AnalyticsBi::Lens::ConstellationScope.new(
        context: department_scoped_context(sports.id), institution: institution).resolve
      assert_equal [ futbol.id ], resolved.pluck(:id)
    end
  end

  test "an institution-level talent (no department) is invisible to a department-scoped specialist" do
    institution = build_institution
    within_tenant(institution) do
      sports = build_department(institution, name: "Deportes")
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Talento institucional", kind: "hobby", department_id: nil)

      resolved = AnalyticsBi::Lens::ConstellationScope.new(
        context: department_scoped_context(sports.id), institution: institution).resolve
      assert_empty resolved
    end
  end

  test "a viewer with the permission but no department grant at all fails closed" do
    institution = build_institution
    within_tenant(institution) do
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Fútbol", kind: "sport")

      resolved = AnalyticsBi::Lens::ConstellationScope.new(context: department_scoped_context, institution: institution).resolve
      assert_empty resolved
    end
  end

  test "the builder assembles a graph of only-authorized talents/students, initials only, never a ranking" do
    institution = build_institution
    within_tenant(institution) do
      term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 12, 31))
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)
      ana = build_student(institution, grade, section, "CB-ANA")
      leo = build_student(institution, grade, section, "CB-LEO")
      futbol = AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Fútbol", kind: "sport")
      piano = AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Piano", kind: "art")
      # Ana plays both; Leo only football — leo should never appear "ranked below" Ana.
      AnalyticsBi::StudentAffinity.create!(institution: institution, student: ana, taxonomy: futbol,
        academic_term: term, source: "teacher_observed", context: "in_school")
      AnalyticsBi::StudentAffinity.create!(institution: institution, student: ana, taxonomy: piano,
        academic_term: term, source: "teacher_observed", context: "out_of_school")
      AnalyticsBi::StudentAffinity.create!(institution: institution, student: leo, taxonomy: futbol,
        academic_term: term, source: "teacher_observed", context: "in_school")

      graph = AnalyticsBi::Lens::ConstellationBuilder.for(context: institution_wide_context, institution: institution)

      assert_equal 2, graph.student_count
      assert_equal 2, graph.taxonomy_count
      futbol_students = graph.student_nodes_for(futbol.id).map(&:name)
      assert_equal [ "Est CB-ANA", "Est CB-LEO" ].sort, futbol_students.sort

      # Non-sensitive client payload: student nodes carry INITIALS as the label,
      # never the full name (§10.1/§10.2 AA posture, same as SeatGrid).
      student_elements = graph.cytoscape_elements.select { |e| e[:data][:type] == "student" }
      assert student_elements.all? { |e| e[:data][:label].length <= 3 }, "graph labels must be initials, not full names"
    end
  end

  test "an empty scope yields an empty, honest graph — never a fake node" do
    institution = build_institution
    within_tenant(institution) do
      graph = AnalyticsBi::Lens::ConstellationBuilder.for(context: institution_wide_context, institution: institution)
      refute graph.any?
      assert_empty graph.cytoscape_elements
    end
  end
end
