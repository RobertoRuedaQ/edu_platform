require "test_helper"

# Slice 8 (BI_DOCUMENT.md §5.6): the sibling-decline read-model signal — "una
# señal para intervención humana, no un veredicto". Computed LIVE (§7/A6),
# never persisted. Exercised with a FIXED as_of date so the recent/baseline
# windows are deterministic regardless of when the suite runs.
class AnalyticsBi::SiblingBondAlertTest < ActiveSupport::TestCase
  AS_OF = Date.new(2026, 6, 1)

  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "sba-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_grade_and_section(institution)
    grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
    section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)
    [ grade, section ]
  end

  def build_sibling(institution, grade, section, mom, first, code)
    student = GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: first, last_name: "Gomez", gender: "female", birthdate: Date.new(2013, 1, 1),
      student_code: code, entry_year: 2023, status: "active")
    gs = Core::GuardianStudent.create!(institution: institution, guardian: mom, student: student, relationship: "madre", status: "active")
    AnalyticsBi::GuardianRelationship.create!(institution: institution, guardian_student: gs,
      relationship_kind: "mother", is_primary_caregiver: true)
    student
  end

  def good_attendance(institution, student, section)
    (20..25).each { |d| Attendance::AttendanceRecord.create!(institution: institution, student: student, group: section, date: AS_OF - d, status: "present") }
  end

  def bad_attendance(institution, student, section)
    (1..5).each { |d| Attendance::AttendanceRecord.create!(institution: institution, student: student, group: section, date: AS_OF - d, status: "absent") }
  end

  test "an alert triggers when TWO OR MORE siblings decline in the same recent window" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      mom = Core::User.create!(email: "sba-mom-#{SecureRandom.hex(4)}@test", name: "Mamá", password: "password-123456")
      ana = build_sibling(institution, grade, section, mom, "Ana", "SBA-ANA")
      leo = build_sibling(institution, grade, section, mom, "Leo", "SBA-LEO")

      [ ana, leo ].each { |s| good_attendance(institution, s, section); bad_attendance(institution, s, section) }

      alerts = AnalyticsBi::Lens::SiblingBondAlert.for(institution: institution, as_of: AS_OF)
      assert_equal 1, alerts.size
      assert_equal [ "Ana", "Leo" ].sort, alerts.first.students.map(&:first_name).sort
    end
  end

  test "only ONE sibling declining does not trigger an alert (needs >= 2)" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      mom = Core::User.create!(email: "sba-mom2-#{SecureRandom.hex(4)}@test", name: "Mamá", password: "password-123456")
      ana = build_sibling(institution, grade, section, mom, "Ana", "SBA2-ANA")
      leo = build_sibling(institution, grade, section, mom, "Leo", "SBA2-LEO")

      good_attendance(institution, ana, section); bad_attendance(institution, ana, section)
      good_attendance(institution, leo, section) # Leo stays fine

      assert_empty AnalyticsBi::Lens::SiblingBondAlert.for(institution: institution, as_of: AS_OF)
    end
  end

  test "no attendance/grade data at all is never treated as a decline (absence of data != decline)" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      mom = Core::User.create!(email: "sba-mom3-#{SecureRandom.hex(4)}@test", name: "Mamá", password: "password-123456")
      build_sibling(institution, grade, section, mom, "Ana", "SBA3-ANA")
      build_sibling(institution, grade, section, mom, "Leo", "SBA3-LEO")

      assert_empty AnalyticsBi::Lens::SiblingBondAlert.for(institution: institution, as_of: AS_OF)
    end
  end

  test "a single child (no siblings) never appears in any alert group" do
    institution = build_institution
    within_tenant(institution) do
      grade, section = build_grade_and_section(institution)
      mom = Core::User.create!(email: "sba-mom4-#{SecureRandom.hex(4)}@test", name: "Mamá", password: "password-123456")
      only_child = build_sibling(institution, grade, section, mom, "Ana", "SBA4-ANA")
      good_attendance(institution, only_child, section); bad_attendance(institution, only_child, section)

      assert_empty AnalyticsBi::Lens::SiblingBondAlert.for(institution: institution, as_of: AS_OF)
    end
  end
end
