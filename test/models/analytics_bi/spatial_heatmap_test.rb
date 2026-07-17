require "test_helper"

# Slice 2 (BI_DOCUMENT.md §10.2): the in-memory heat derivation. HIGHER heat ==
# more attention needed; a student with no grade AND no attendance data yet has
# heat nil (a real empty state, never a misleading 0). Exercised directly under
# the tenant GUC.
class AnalyticsBi::SpatialHeatmapTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "hm-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_student(institution, code)
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023, status: "active")
  end

  def grade!(institution, subject, student, score)
    enrollment = Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      term: "2026-1", status: "enrolled")
    Schedules::Assessment.create!(institution: institution, enrollment: enrollment, kind: "quiz",
      title: "Quiz", term: "2026-1", score: score)
  end

  def attend!(institution, student, section, status, days_ago)
    Attendance::AttendanceRecord.create!(institution: institution, student: student, group: section,
      date: days_ago.days.ago.to_date, status: status)
  end

  test "heat is high for a struggling student, low for a thriving one, and nil with no data" do
    institution = build_institution
    within_tenant(institution) do
      section = GroupManagement::Section.create!(institution: institution, name: "9°A", academic_year: 2026)
      grade_level = GroupManagement::GradeLevel.create!(institution: institution, name: "Noveno", level_number: 9)
      subject = Schedules::Subject.create!(institution: institution, grade_level: grade_level, name: "Álgebra",
        code: "HM-SUB", term: "2026-1")

      ana = build_student(institution, "HM-ANA")   # thriving
      beto = build_student(institution, "HM-BETO") # struggling
      caro = build_student(institution, "HM-CARO") # no data yet

      grade!(institution, subject, ana, 5.0)
      attend!(institution, ana, section, "present", 1)
      attend!(institution, ana, section, "present", 2)

      grade!(institution, subject, beto, 1.0)
      attend!(institution, beto, section, "absent", 1)
      attend!(institution, beto, section, "absent", 2)

      heat = AnalyticsBi::Lens::SpatialHeatmap.for(institution: institution,
        student_ids: [ ana.id, beto.id, caro.id ])

      assert heat[ana.id].known?
      refute heat[ana.id].needs_attention
      assert_operator heat[ana.id].heat, :<, AnalyticsBi::Lens::SpatialHeatmap::ATTENTION_THRESHOLD
      assert_match(/\Ahsl\(/, heat[ana.id].hsl)

      assert heat[beto.id].known?
      assert heat[beto.id].needs_attention
      assert_operator heat[beto.id].heat, :>=, AnalyticsBi::Lens::SpatialHeatmap::ATTENTION_THRESHOLD

      refute heat[caro.id].known?
      assert_nil heat[caro.id].heat
      refute heat[caro.id].needs_attention
      assert_equal "var(--heat-unknown)", heat[caro.id].hsl
    end
  end

  test "a single available signal still yields heat (attendance only, no grades)" do
    institution = build_institution
    within_tenant(institution) do
      section = GroupManagement::Section.create!(institution: institution, name: "9°B", academic_year: 2026)
      dani = build_student(institution, "HM-DANI")
      attend!(institution, dani, section, "absent", 1)
      attend!(institution, dani, section, "absent", 2)

      heat = AnalyticsBi::Lens::SpatialHeatmap.for(institution: institution, student_ids: [ dani.id ])

      assert heat[dani.id].known?
      assert_in_delta 1.0, heat[dani.id].heat, 0.001 # 0% attendance, no grade -> full heat
      assert heat[dani.id].needs_attention
    end
  end
end
