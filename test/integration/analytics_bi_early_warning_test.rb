require "test_helper"

# Lens 6 — "Alertas Tempranas" (BI_DOCUMENT.md §5.8 amendment). HTTP-level
# acceptance: SUPERVISION, institution-wide ONLY. The default persona (lacking
# hps.early_warning.view) is denied; a holder sees only real, live-computed
# signals — never anything auto-sent (this controller only reads and links out
# to existing surfaces).
class AnalyticsBiEarlyWarningTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member # default grant does NOT include hps.early_warning.view
  end

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def as_viewer(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "hps_ew_viewer",
        permission_keys: %w[hps.early_warning.view], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "the default persona (no hps.early_warning.view) is denied (403)" do
    get analytics_bi_early_warnings_path
    assert_response :forbidden
  end

  test "an empty institution shows the honest empty state" do
    as_viewer do
      get analytics_bi_early_warnings_path
      assert_response :success
      assert_select ".empty-state__title", text: "Sin alertas activas"
    end
  end

  test "a flagged student appears with a link to their family core and NEVER an auto-sent message" do
    term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1", status: "active",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 12, 31))
    end
    student = within_tenant(@institution) do
      grade = GroupManagement::GradeLevel.create!(institution: @institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: @institution, grade_level: grade, name: "9A", academic_year: 2026)
      s = GroupManagement::Student.create!(institution: @institution, grade_level: grade, section: section,
        first_name: "Ana", last_name: "P", gender: "female", birthdate: Date.new(2013, 3, 1),
        student_code: "EW-HTTP", entry_year: 2023, status: "active")
      AnalyticsBi::HpsTermSnapshot.create!(institution: @institution, student: s, academic_term: term,
        captured_on: Date.current, payload: { "heat" => 0.9 })
      s
    end

    as_viewer do
      get analytics_bi_early_warnings_path
      assert_response :success
      assert_match "Ana", response.body
      assert_match "Riesgo académico", response.body
      assert_match analytics_bi_family_core_path(student.id), response.body
      # No delivery mechanism exists on this page beyond a link to the
      # EXISTING compose flow — never an auto-sent message.
      assert_no_match(/mensaje enviado/i, response.body)
    end
  end
end
