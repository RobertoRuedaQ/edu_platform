require "test_helper"

# Slice 4 (BI_DOCUMENT.md §7): AnalyticsBi::Hps::Snapshotter congeals one
# HpsTermSnapshot per active student, with a jsonb payload of TERM-scoped
# metrics. Exercised under the tenant GUC (RLS FORCE) against known fixture data.
class AnalyticsBi::HpsTermSnapshotterTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "hs-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_term(institution)
    Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
      starts_on: Date.new(2026, 1, 15), ends_on: Date.new(2026, 12, 15))
  end

  def build_grade(institution)
    GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
  end

  def build_section(institution, grade)
    GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9°A", academic_year: 2026)
  end

  def build_student(institution, grade, section, code)
    GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: "Est", last_name: code, gender: "female", birthdate: Date.new(2013, 3, 1),
      student_code: code, entry_year: 2023, status: "active")
  end

  def grade_student(institution, term, student, score)
    subject = Schedules::Subject.create!(institution: institution, name: "Matemáticas", code: "MAT-#{SecureRandom.hex(2)}", term: "2026-1")
    enrollment = Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      academic_term: term, term: "2026-1")
    Schedules::Assessment.create!(institution: institution, enrollment: enrollment, kind: "exam",
      title: "Parcial", term: "2026-1", score: score)
  end

  def record_attendance(institution, section, student, present:, absent:)
    day = Date.new(2026, 3, 1)
    present.times do |i|
      Attendance::AttendanceRecord.create!(institution: institution, student: student, group: section,
        date: day + i, status: "present")
    end
    absent.times do |i|
      Attendance::AttendanceRecord.create!(institution: institution, student: student, group: section,
        date: day + present + i, status: "absent")
    end
  end

  test "computes one snapshot per active student with correct term-scoped payload" do
    institution = build_institution
    within_tenant(institution) do
      term = build_term(institution)
      grade = build_grade(institution)
      section = build_section(institution, grade)
      ana = build_student(institution, grade, section, "HS-ANA")
      leo = build_student(institution, grade, section, "HS-LEO")
      mia = build_student(institution, grade, section, "HS-MIA")
      GroupManagement::PlacementBackfill.run(institution: institution)

      grade_student(institution, term, ana, 4.0)           # grade signal 4.0/5 = 0.8
      record_attendance(institution, section, ana, present: 2, absent: 0)  # 1.0
      record_attendance(institution, section, leo, present: 1, absent: 1)  # 0.5, no grade
      # mia: no grade, no attendance -> all nil

      snapshots = AnalyticsBi::Hps::Snapshotter.call(institution: institution, academic_term: term)
      assert_equal 3, snapshots.size, "one snapshot per active student"

      ana_snap = AnalyticsBi::HpsTermSnapshot.find_by(student_id: ana.id, academic_term_id: term.id)
      assert_in_delta 4.0, ana_snap.payload["average_grade"], 0.001
      assert_in_delta 1.0, ana_snap.payload["attendance_rate"], 0.001
      # wellbeing = mean(0.8, 1.0) = 0.9 ; heat = 0.1
      assert_in_delta 0.9, ana_snap.payload["wellbeing"], 0.001
      assert_in_delta 0.1, ana_snap.payload["heat"], 0.001
      assert_equal section.id, ana_snap.payload["section_id"]
      assert_equal "9°A", ana_snap.payload["section_name"]
      assert_equal "Grado 9", ana_snap.payload["grade_level_name"]

      leo_snap = AnalyticsBi::HpsTermSnapshot.find_by(student_id: leo.id, academic_term_id: term.id)
      assert_nil leo_snap.payload["average_grade"], "no graded assessment -> nil, never a misleading 0"
      assert_in_delta 0.5, leo_snap.payload["attendance_rate"], 0.001
      assert_in_delta 0.5, leo_snap.payload["wellbeing"], 0.001

      mia_snap = AnalyticsBi::HpsTermSnapshot.find_by(student_id: mia.id, academic_term_id: term.id)
      assert_nil mia_snap.payload["average_grade"]
      assert_nil mia_snap.payload["attendance_rate"]
      assert_nil mia_snap.payload["heat"], "no signals at all -> nil heat, a real empty state"
    end
  end

  test "re-running for the same (student, term) updates the row instead of duplicating it" do
    institution = build_institution
    within_tenant(institution) do
      term = build_term(institution)
      grade = build_grade(institution)
      section = build_section(institution, grade)
      ana = build_student(institution, grade, section, "HS-ANA")

      first = AnalyticsBi::Hps::Snapshotter.call(institution: institution, academic_term: term).first
      second = AnalyticsBi::Hps::Snapshotter.call(institution: institution, academic_term: term).first

      assert_equal first.id, second.id
      assert_equal 1, AnalyticsBi::HpsTermSnapshot.where(student_id: ana.id, academic_term_id: term.id).count
    end
  end
end
