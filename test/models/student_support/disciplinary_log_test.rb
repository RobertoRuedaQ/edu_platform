require "test_helper"

# guidelines/CLOSURE_PLAN.md §3.1/Fase B: StudentSupport::DisciplinaryLog, the
# real replacement for the DisciplinaryLogRoster stub. Molde `counseling` —
# tenant-scoped, identity-accountable author, append-only (no update/destroy
# route exists). Exercised directly under the tenant GUC (RLS FORCE).
class StudentSupport::DisciplinaryLogTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "dl-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_student(institution)
    grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
    section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)
    GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: "Ana", last_name: "P", gender: "female", birthdate: Date.new(2013, 3, 1),
      student_code: "DL-ANA", entry_year: 2023, status: "active")
  end

  def build_reporter(institution)
    user = Core::User.create!(email: "reporter-#{SecureRandom.hex(4)}@test", name: "Docente Reportante",
      password: "password-123456")
    institution.memberships.create!(user: user)
  end

  test "a closed category is enforced by the DB CHECK (bypassing app validation)" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution)
      reporter = build_reporter(institution)
      log = StudentSupport::DisciplinaryLog.new(institution: institution, student: student, reported_by: reporter,
        category: "invented", description: "x", occurred_at: Date.current)

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { log.save!(validate: false) }
      end
    end
  end

  test "category_label and reported_by_name expose human-readable text" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution)
      reporter = build_reporter(institution)
      log = StudentSupport::DisciplinaryLog.create!(institution: institution, student: student, reported_by: reporter,
        category: "attendance", description: "Tercera ausencia sin excusa.", occurred_at: Date.current)

      assert_equal "Ausentismo", log.category_label
      assert_equal "Docente Reportante", log.reported_by_name
    end
  end

  test "group_id delegates to the student — the scope-covering descriptor a group-scoped grant reads" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution)
      reporter = build_reporter(institution)
      log = StudentSupport::DisciplinaryLog.create!(institution: institution, student: student, reported_by: reporter,
        category: "conduct", description: "Conflicto en el descanso.", occurred_at: Date.current)

      assert_equal student.group_id, log.group_id
    end
  end

  test "multiple logs for the same student are all kept — append-only, never overwritten" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution)
      reporter = build_reporter(institution)
      2.times do |i|
        StudentSupport::DisciplinaryLog.create!(institution: institution, student: student, reported_by: reporter,
          category: "conduct", description: "Incidente #{i}.", occurred_at: Date.current - i)
      end

      assert_equal 2, StudentSupport::DisciplinaryLog.where(student_id: student.id).count
    end
  end
end
