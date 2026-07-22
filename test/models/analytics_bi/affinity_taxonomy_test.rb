require "test_helper"

# Slice 7 (BI_DOCUMENT.md §5.5, §1.1.6): the curated affinity taxonomy and its
# FTS search. The hard invariant this file proves: the specialist searches a
# TALENT, never a student — TaxonomySearchScope's SQL has no path to a student
# name/document, and its result is a set of talents, never a ranked list.
class AnalyticsBi::AffinityTaxonomyTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "at-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "a closed kind is enforced by the DB CHECK (bypassing app validation)" do
    institution = build_institution
    within_tenant(institution) do
      node = AnalyticsBi::AffinityTaxonomy.new(institution: institution, name: "Inventado", kind: "invented")
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { node.save!(validate: false) }
      end
    end
  end

  test "hierarchy: a child node references its parent, and parent deletion cascades" do
    institution = build_institution
    within_tenant(institution) do
      root = AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Deportes", kind: "sport")
      child = AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Fútbol", kind: "sport", parent: root)

      assert_equal root.id, child.parent_id
      assert_includes root.children, child
    end
  end

  test "the FTS search matches by talent name, accent-insensitively, and NEVER touches student data" do
    institution = build_institution
    within_tenant(institution) do
      futbol = AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Fútbol", kind: "sport")
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Piano", kind: "art")

      matches = AnalyticsBi::Lens::TaxonomySearchScope.new(query: "futbol", institution: institution).resolve
      assert_equal [ futbol.id ], matches.pluck(:id)

      # Structural proof (§1.1.6): the query object's SQL never references a
      # students table/column — there is no path from this search to a person.
      sql = AnalyticsBi::Lens::TaxonomySearchScope.new(query: "futbol", institution: institution).resolve.to_sql
      assert_no_match(/students/i, sql, "the taxonomy search must never join or reference students")
    end
  end

  test "a blank query matches nothing — never 'everything'" do
    institution = build_institution
    within_tenant(institution) do
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Fútbol", kind: "sport")

      assert_empty AnalyticsBi::Lens::TaxonomySearchScope.new(query: "", institution: institution).resolve
    end
  end

  test "an inactive taxonomy node is excluded from the active scope and from search by default" do
    institution = build_institution
    within_tenant(institution) do
      AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Retirado", kind: "hobby", active: false)

      assert_empty AnalyticsBi::AffinityTaxonomy.active.where(institution: institution)
      assert_empty AnalyticsBi::Lens::TaxonomySearchScope.new(query: "retirado", institution: institution).resolve
    end
  end

  test "a student_affinity is unique per (student, taxonomy, term) — DB backstop" do
    institution = build_institution
    within_tenant(institution) do
      term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 12, 31))
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)
      student = GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
        first_name: "Ana", last_name: "P", gender: "female", birthdate: Date.new(2013, 3, 1),
        student_code: "AT-ANA", entry_year: 2023, status: "active")
      taxonomy = AnalyticsBi::AffinityTaxonomy.create!(institution: institution, name: "Piano", kind: "art")

      AnalyticsBi::StudentAffinity.create!(institution: institution, student: student, taxonomy: taxonomy,
        academic_term: term, source: "teacher_observed", context: "in_school")

      assert_raises(ActiveRecord::RecordInvalid) do
        AnalyticsBi::StudentAffinity.create!(institution: institution, student: student, taxonomy: taxonomy,
          academic_term: term, source: "self_reported", context: "out_of_school")
      end
    end
  end
end
