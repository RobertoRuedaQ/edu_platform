require "test_helper"

# Lens 6 — "Alertas Tempranas" (BI_DOCUMENT.md §5.8 amendment, guidelines/
# CLOSURE_PLAN.md §3.2/Fase C). AnalyticsBi::Lens::EarlyWarningScope is a pure
# read-model, computed live, that synthesizes signals ALREADY built by prior
# slices. The hard invariant this file proves: the umbrella permission
# (hps.early_warning.view) never leaks a signal the viewer lacks the SPECIFIC
# underlying permission for.
class AnalyticsBi::EarlyWarningScopeTest < ActiveSupport::TestCase
  FakeContext = Struct.new(:perms) do
    def can?(key, _resource = nil) = perms.include?(key.to_s)
  end

  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "ew-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_term(institution)
    Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
      starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 12, 31))
  end

  def build_student(institution, code)
    grade = GroupManagement::GradeLevel.find_or_create_by!(institution: institution, name: "Grado 9") { |g| g.level_number = 9 }
    section = GroupManagement::Section.find_or_create_by!(institution: institution, grade_level: grade, name: "9A") { |s| s.academic_year = 2026 }
    GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: "Est", last_name: code, gender: "female", birthdate: Date.new(2013, 3, 1),
      student_code: code, entry_year: 2023, status: "active")
  end

  def full_context
    FakeContext.new(%w[disciplinary_logs.manage hps.family.view hps.aura.view])
  end

  test "a student with no signals at all is never flagged — an honest, non-empty-by-default list" do
    institution = build_institution
    within_tenant(institution) do
      build_student(institution, "EW-CALM")

      assert_empty AnalyticsBi::Lens::EarlyWarningScope.new(context: full_context, institution: institution).resolve
    end
  end

  test "a high heat from the active term's HPS snapshot flags the student" do
    institution = build_institution
    within_tenant(institution) do
      term = build_term(institution)
      student = build_student(institution, "EW-HOT")
      AnalyticsBi::HpsTermSnapshot.create!(institution: institution, student: student, academic_term: term,
        captured_on: Date.current, payload: { "heat" => 0.9 })

      flags = AnalyticsBi::Lens::EarlyWarningScope.new(context: full_context, institution: institution).resolve
      assert_equal 1, flags.size
      assert_includes flags.first.signal_labels, "Riesgo académico/asistencia"
    end
  end

  test "a heat below the threshold does NOT flag the student" do
    institution = build_institution
    within_tenant(institution) do
      term = build_term(institution)
      student = build_student(institution, "EW-OK")
      AnalyticsBi::HpsTermSnapshot.create!(institution: institution, student: student, academic_term: term,
        captured_on: Date.current, payload: { "heat" => 0.2 })

      assert_empty AnalyticsBi::Lens::EarlyWarningScope.new(context: full_context, institution: institution).resolve
    end
  end

  test "a recent disciplinary log flags the student, but ONLY for a viewer holding disciplinary_logs.manage" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "EW-DISC")
      reporter_user = Core::User.create!(email: "ew-rep-#{SecureRandom.hex(4)}@test", name: "Rep", password: "password-123456")
      reporter = institution.memberships.create!(user: reporter_user)
      StudentSupport::DisciplinaryLog.create!(institution: institution, student: student, reported_by: reporter,
        category: "conduct", description: "x", occurred_at: Date.current)

      with_it = AnalyticsBi::Lens::EarlyWarningScope.new(context: full_context, institution: institution).resolve
      assert_equal 1, with_it.size

      without_it = AnalyticsBi::Lens::EarlyWarningScope.new(context: FakeContext.new([]), institution: institution).resolve
      assert_empty without_it, "the signal must be invisible entirely without disciplinary_logs.manage, never leaked"
    end
  end

  test "an old disciplinary log (outside the recent window) does not flag the student" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "EW-OLD")
      reporter_user = Core::User.create!(email: "ew-rep2-#{SecureRandom.hex(4)}@test", name: "Rep", password: "password-123456")
      reporter = institution.memberships.create!(user: reporter_user)
      StudentSupport::DisciplinaryLog.create!(institution: institution, student: student, reported_by: reporter,
        category: "conduct", description: "x", occurred_at: Date.current - 90)

      assert_empty AnalyticsBi::Lens::EarlyWarningScope.new(context: full_context, institution: institution).resolve
    end
  end

  test "a student in an active sibling-decline alert is flagged, but ONLY for a viewer holding hps.family.view" do
    institution = build_institution
    within_tenant(institution) do
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)
      mom = Core::User.create!(email: "ew-mom-#{SecureRandom.hex(4)}@test", name: "Mamá", password: "password-123456")
      [ "EW-SIB1", "EW-SIB2" ].map do |code|
        student = GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
          first_name: "Est", last_name: code, gender: "female", birthdate: Date.new(2013, 3, 1),
          student_code: code, entry_year: 2023, status: "active")
        gs = Core::GuardianStudent.create!(institution: institution, guardian: mom, student: student, relationship: "madre", status: "active")
        AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs, relationship_kind: "mother", is_primary_caregiver: true)
        (20..25).each { |d| Attendance::AttendanceRecord.create!(institution: institution, student: student, group: section, date: Date.current - d, status: "present") }
        (1..5).each { |d| Attendance::AttendanceRecord.create!(institution: institution, student: student, group: section, date: Date.current - d, status: "absent") }
      end

      with_it = AnalyticsBi::Lens::EarlyWarningScope.new(context: full_context, institution: institution).resolve
      assert_equal 2, with_it.size
      assert(with_it.all? { |f| f.signal_labels.include?("Alerta de lazos fraternales") })

      without_it = AnalyticsBi::Lens::EarlyWarningScope.new(context: FakeContext.new([]), institution: institution).resolve
      assert_empty without_it, "the sibling alert signal must be invisible without hps.family.view"
    end
  end

  test "care_aura_present is informational only — it never triggers a flag by itself" do
    institution = build_institution
    within_tenant(institution) do
      term = build_term(institution)
      student = build_student(institution, "EW-AURA")
      counselor_user = Core::User.create!(email: "ew-counselor-#{SecureRandom.hex(4)}@test", name: "Orientador", password: "password-123456")
      counselor = institution.memberships.create!(user: counselor_user)
      AnalyticsBi::CareAura.create!(institution: institution, student: student, aura_kind: "quiet_space",
        guidance_text: "x", authored_by_counselor: counselor, effective_from: Date.current, academic_term: term)

      assert_empty AnalyticsBi::Lens::EarlyWarningScope.new(context: full_context, institution: institution).resolve
    end
  end
end
