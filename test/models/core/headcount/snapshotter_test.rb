require "test_helper"

class Core::Headcount::SnapshotterTest < ActiveSupport::TestCase
  def build_institution
    slug = "snap-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  # Snapshotter trusts its caller to have already fixed the tenant GUC — same
  # contract every Query object in app/domains/* has with TenantScoped. Tests
  # here replicate that manually, the way Core::Headcount::SnapshotJob does
  # for real (see snapshot_job_test.rb for the job-level, GUC-handling test).
  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  test "counts only active students, ignores inactive ones, and freezes the active term's label" do
    institution = build_institution

    within_tenant(institution) do
      Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 6", level_number: 6)

      2.times do |i|
        GroupManagement::Student.create!(institution: institution, grade_level: grade,
          first_name: "Activo#{i}", last_name: "Prueba", gender: "male", birthdate: Date.new(2015, 1, 1),
          student_code: "A#{i}-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")
      end
      GroupManagement::Student.create!(institution: institution, grade_level: grade,
        first_name: "Inactivo", last_name: "Prueba", gender: "female", birthdate: Date.new(2015, 1, 1),
        student_code: "X-#{SecureRandom.hex(2)}", entry_year: 2026, status: "inactive")

      snapshot = Core::Headcount::Snapshotter.call(institution: institution, as_of: Date.current)

      assert_equal 2, snapshot.headcount
      assert_equal "2026-1", snapshot.academic_term_label
      assert_equal({ "Grado 6" => 2 }, snapshot.breakdown)
    end
  end

  test "re-running for the same as_of updates the existing snapshot, not a new row" do
    institution = build_institution

    within_tenant(institution) do
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 7", level_number: 7)
      GroupManagement::Student.create!(institution: institution, grade_level: grade,
        first_name: "Uno", last_name: "Prueba", gender: "male", birthdate: Date.new(2014, 1, 1),
        student_code: "U-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")

      first = Core::Headcount::Snapshotter.call(institution: institution, as_of: Date.current)
      assert_equal 1, first.headcount

      GroupManagement::Student.create!(institution: institution, grade_level: grade,
        first_name: "Dos", last_name: "Prueba", gender: "female", birthdate: Date.new(2014, 1, 1),
        student_code: "D-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")

      second = Core::Headcount::Snapshotter.call(institution: institution, as_of: Date.current)
      assert_equal first.id, second.id
      assert_equal 2, second.reload.headcount
      assert_equal 1, ControlPlane::StudentHeadcountSnapshot.for_institution(institution).count
    end
  end

  # Regression for F3 (v1.15.0, Cav./B2 model half): adding a real
  # enrollments.academic_term_id join must NOT change what the headcount
  # counts. Two students with the SAME status ("active") but different term
  # enrollment states (one enrolled in the active term, one enrolled only in
  # a past term, one with no enrollment at all) must all count identically —
  # proving the snapshot still depends solely on students.status, never on
  # Schedules::Enrollment/academic_term_id.
  test "REGRESSION: headcount is unaffected by term enrollment state (F3 — only students.status counts)" do
    institution = build_institution

    within_tenant(institution) do
      active_term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      past_term = Core::AcademicTerm.create!(institution: institution, code: "2025-2", name: "2025-2",
        starts_on: Date.new(2025, 7, 1), ends_on: Date.new(2025, 12, 15), status: "closed")
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 6", level_number: 6)
      subject = Schedules::Subject.create!(institution: institution, name: "Álgebra", code: "MAT-1", term: "2026-1")

      enrolled_active = GroupManagement::Student.create!(institution: institution, grade_level: grade,
        first_name: "Matriculado", last_name: "Activo", gender: "male", birthdate: Date.new(2015, 1, 1),
        student_code: "MA-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")
      Schedules::Enrollment.create!(institution: institution, student: enrolled_active, subject: subject,
        term: "2026-1", academic_term: active_term, status: "enrolled")

      enrolled_past_only = GroupManagement::Student.create!(institution: institution, grade_level: grade,
        first_name: "Matriculado", last_name: "SoloPasado", gender: "female", birthdate: Date.new(2015, 1, 1),
        student_code: "MP-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")
      Schedules::Enrollment.create!(institution: institution, student: enrolled_past_only, subject: subject,
        term: "2025-2", academic_term: past_term, status: "enrolled")

      not_enrolled_at_all = GroupManagement::Student.create!(institution: institution, grade_level: grade,
        first_name: "SinMatricula", last_name: "Prueba", gender: "male", birthdate: Date.new(2015, 1, 1),
        student_code: "NE-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")

      snapshot = Core::Headcount::Snapshotter.call(institution: institution, as_of: Date.current)

      # All three are status "active" — the headcount must count all three,
      # regardless of who has a real term enrollment and who doesn't.
      assert_equal 3, snapshot.headcount
      assert_equal({ "Grado 6" => 3 }, snapshot.breakdown)
    end
  end

  test "audits the push as a system action" do
    institution = build_institution

    within_tenant(institution) do
      snapshot = Core::Headcount::Snapshotter.call(institution: institution, as_of: Date.current)
      event = ControlPlane::AuditEvent.find_by(action: "headcount.pushed", target_id: snapshot.id)
      assert event.present?
      assert_nil event.platform_admin_id
    end
  end
end
