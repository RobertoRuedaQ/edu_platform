require "test_helper"

class AnalyticsBiTest < ActionDispatch::IntegrationTest
  setup { @user, @institution = sign_in_as_member }

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_student!(institution, code:, status: "active")
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023, status: status)
  end

  def as_principal(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "principal", permission_keys: %w[institution_dashboard.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_bi_auditor(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "bi_auditor", permission_keys: %w[cross_tenant_reports.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "institution dashboard requires institution_dashboard.view" do
    with_grants { get "/analytics_bi/dashboard"; assert_response :forbidden }

    as_principal do
      get "/analytics_bi/dashboard"
      assert_response :success
      assert_select ".stat__value", text: "0" # zero students yet, a real empty state — not the old hardcoded stub "187"
    end
  end

  # S1's stub was replaced by real numbers (v1.34.0) — this is the acceptance
  # case for AnalyticsBi::InstitutionDashboard, driven through the controller.
  test "acceptance: the dashboard shows real KPIs computed from this institution's own data" do
    section = within_tenant(@institution) { GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026) }
    student_a = within_tenant(@institution) { build_student!(@institution, code: "BI-001") }
    student_b = within_tenant(@institution) { build_student!(@institution, code: "BI-002") }
    within_tenant(@institution) { build_student!(@institution, code: "BI-003", status: "inactive") }

    grade_level = within_tenant(@institution) { GroupManagement::GradeLevel.create!(institution: @institution, name: "Noveno", level_number: 9) }
    subject = within_tenant(@institution) { Schedules::Subject.create!(institution: @institution, grade_level: grade_level, name: "Álgebra", code: "BI-SUB", term: "2026-1") }
    within_tenant(@institution) do
      enrollment_a = Schedules::Enrollment.create!(institution: @institution, student: student_a, subject: subject, term: "2026-1", status: "enrolled")
      enrollment_b = Schedules::Enrollment.create!(institution: @institution, student: student_b, subject: subject, term: "2026-1", status: "enrolled")
      Schedules::Assessment.create!(institution: @institution, enrollment: enrollment_a, kind: "quiz", title: "Quiz 1", term: "2026-1", score: 4.0)
      Schedules::Assessment.create!(institution: @institution, enrollment: enrollment_b, kind: "quiz", title: "Quiz 1", term: "2026-1", score: 3.0)
    end

    within_tenant(@institution) do
      Attendance::AttendanceRecord.create!(institution: @institution, student: student_a, group: section, date: Date.current, status: "present")
      Attendance::AttendanceRecord.create!(institution: @institution, student: student_b, group: section, date: Date.current, status: "absent")
    end

    within_tenant(@institution) do
      ControlPlane::StudentHeadcountSnapshot.create!(institution: @institution, as_of_date: 1.month.ago.to_date, headcount: 1)
      ControlPlane::StudentHeadcountSnapshot.create!(institution: @institution, as_of_date: Date.current, headcount: 2)
    end

    as_principal do
      get "/analytics_bi/dashboard"
      assert_response :success
      assert_select ".stat__value", text: "2"    # total_students: only the two "active" students
      assert_select ".stat__value", text: "3.5"  # avg_grade: (4.0 + 3.0) / 2
      assert_select ".stat__value", text: "50.0%" # attendance_rate: 1 present of 2 records
      assert_match "Álgebra", response.body       # grades_by_subject label
    end
  end

  test "cross_tenant_reports requires cross_tenant_reports.view" do
    with_grants { get "/analytics_bi/cross_tenant_reports"; assert_response :forbidden }

    as_bi_auditor do
      get "/analytics_bi/cross_tenant_reports"
      assert_response :success
      assert_select ".alert__title", text: "Modo auditoría"
      assert_select "td", text: "Universidad Andina"
    end
  end

  # --- the security invariant Apéndice A calls out explicitly ---------------

  test "institution_dashboard.view never implies cross_tenant_reports.view" do
    as_principal do
      get "/analytics_bi/cross_tenant_reports"
      assert_response :forbidden
    end
  end

  test "cross_tenant_reports.view never implies institution_dashboard.view" do
    as_bi_auditor do
      get "/analytics_bi/dashboard"
      assert_response :forbidden
    end
  end

  test "the default demo persona holds neither analytics permission" do
    get "/analytics_bi/dashboard"
    assert_response :forbidden

    get "/analytics_bi/cross_tenant_reports"
    assert_response :forbidden
  end

  test "the default demo persona's dashboard nav never shows Analítica or Auditoría BI" do
    get "/"
    assert_response :success
    assert_select "a.tile", text: /Analítica/, count: 0
    assert_select "a.tile", text: /Auditoría BI/, count: 0
  end
end
