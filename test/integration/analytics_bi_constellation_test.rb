require "test_helper"

# Slice 7 (BI_DOCUMENT.md §4/§5.5): HTTP-level acceptance for Lens 3. SUPERVISION
# (molde #4) — every action is gated by hps.constellation.view/hps.affinity.author;
# the default persona (which lacks both) is denied. Scope acceptance (institution-
# wide vs department) is the "caso de María" spirit already established by Lens 1.
class AnalyticsBiConstellationTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member # default grant does NOT include hps.*
    within_tenant(@institution) do
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1", status: "active",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 12, 31))
      @grade = GroupManagement::GradeLevel.create!(institution: @institution, name: "Grado 9", level_number: 9)
      @section = GroupManagement::Section.create!(institution: @institution, grade_level: @grade, name: "9A", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, grade_level: @grade, section: @section,
        first_name: "Ana", last_name: "P", gender: "female", birthdate: Date.new(2013, 3, 1),
        student_code: "AB-ANA", entry_year: 2023, status: "active")
      @sports = StaffManagement::Department.create!(institution: @institution, name: "Deportes", code: "DEP", kind: "academic")
      @futbol = AnalyticsBi::AffinityTaxonomy.create!(institution: @institution, name: "Fútbol", kind: "sport", department: @sports)
      AnalyticsBi::StudentAffinity.create!(institution: @institution, student: @student, taxonomy: @futbol,
        academic_term: @term, source: "teacher_observed", context: "in_school")
    end
  end

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def as_viewer(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "hps_viewer",
        permission_keys: %w[hps.constellation.view], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_department_viewer(department, &block)
    with_grants(
      Authorization::Assignment.new(role_key: "hps_dept_viewer",
        permission_keys: %w[hps.constellation.view], scope_type: :department, scope_id: department.id),
      &block
    )
  end

  def as_author(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "hps_author",
        permission_keys: %w[hps.affinity.author], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "the default persona (no hps.constellation.view) is denied the constellation (403)" do
    get analytics_bi_constellations_path
    assert_response :forbidden
  end

  test "an institution-wide hps.constellation.view holder sees the graph" do
    as_viewer do
      get analytics_bi_constellations_path
      assert_response :success
      assert_match "Fútbol", response.body
    end
  end

  test "a department-scoped viewer sees only their department's talents" do
    arts = within_tenant(@institution) { StaffManagement::Department.create!(institution: @institution, name: "Artes", code: "ART", kind: "academic") }

    as_department_viewer(@sports) do
      get analytics_bi_constellations_path
      assert_response :success
      assert_match "Fútbol", response.body
    end

    as_department_viewer(arts) do
      get analytics_bi_constellations_path
      assert_response :success
      assert_no_match(/Fútbol/, response.body)
    end
  end

  test "the default persona (no hps.affinity.author) is denied the authoring surface (403)" do
    get new_analytics_bi_student_affinity_path(student_id: @student.id)
    assert_response :forbidden

    post analytics_bi_student_affinities_path, params: { student_id: @student.id, taxonomy_id: @futbol.id }
    assert_response :forbidden
  end

  test "an hps.affinity.author registers a teacher-observed affinity" do
    piano = within_tenant(@institution) { AnalyticsBi::AffinityTaxonomy.create!(institution: @institution, name: "Piano", kind: "art") }

    as_author do
      assert_difference -> { AnalyticsBi::StudentAffinity.count }, 1 do
        post analytics_bi_student_affinities_path,
          params: { student_id: @student.id, taxonomy_id: piano.id, context: "out_of_school" }
      end
      assert_response :redirect

      affinity = within_tenant(@institution) { AnalyticsBi::StudentAffinity.last }
      assert_equal "teacher_observed", affinity.source
      assert_equal "out_of_school", affinity.context
    end
  end

  test "registering the same talent twice for the same student/term is a friendly no-op, not a 500" do
    as_author do
      post analytics_bi_student_affinities_path, params: { student_id: @student.id, taxonomy_id: @futbol.id }
      assert_response :redirect
      assert_equal 1, within_tenant(@institution) { AnalyticsBi::StudentAffinity.where(student_id: @student.id, taxonomy_id: @futbol.id).count }
    end
  end
end
