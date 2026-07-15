require "test_helper"

class ReportCards::ComputationTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  setup do
    slug = "rc-comp-#{SecureRandom.hex(4)}"
    @institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(@institution) do
      @active_term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "Ríos",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "RC-001", entry_year: 2023, section: @section)
      @subject = Schedules::Subject.create!(institution: @institution, name: "Álgebra", code: "MAT-RC",
        term: @active_term.code)
      @enrollment = Schedules::Enrollment.create!(institution: @institution, student: @student, subject: @subject,
        term: @active_term.code, academic_term: @active_term, status: "enrolled")
    end
  end

  test "normalizes each assessment to the 5.0 scale and weights them before averaging" do
    within_tenant(@institution) do
      # normalized 5.0, weight 3.0 -> contributes 15.0
      @enrollment.assessments.create!(institution: @institution, kind: "parcial", title: "Parcial 1",
        term: @active_term.code, score: 5.0, max_score: 5.0, weight: 3.0)
      # normalized 3.0, weight 2.0 -> contributes 6.0
      @enrollment.assessments.create!(institution: @institution, kind: "quiz", title: "Quiz 1",
        term: @active_term.code, score: 3.0, max_score: 5.0, weight: 2.0)

      result = ReportCards::Computation.call(student: @student, academic_term: @active_term, institution: @institution)

      assert_equal 1, result.lines.size
      line = result.lines.first
      assert_equal @subject.id, line.subject_id
      assert_equal @subject.name, line.subject_name
      assert_equal BigDecimal("4.2"), line.average # (15.0 + 6.0) / 5.0
      assert_equal BigDecimal("4.2"), result.overall_average
    end
  end

  test "a subject with no graded assessments contributes no line, not a zero" do
    within_tenant(@institution) do
      @enrollment.assessments.create!(institution: @institution, kind: "quiz", title: "Pendiente",
        term: @active_term.code, score: nil)

      result = ReportCards::Computation.call(student: @student, academic_term: @active_term, institution: @institution)

      assert_empty result.lines
      assert_nil result.overall_average
    end
  end

  test "overall_average is the simple average of the per-subject lines" do
    within_tenant(@institution) do
      other_subject = Schedules::Subject.create!(institution: @institution, name: "Español", code: "ESP-RC",
        term: @active_term.code)
      other_enrollment = Schedules::Enrollment.create!(institution: @institution, student: @student,
        subject: other_subject, term: @active_term.code, academic_term: @active_term, status: "enrolled")

      @enrollment.assessments.create!(institution: @institution, kind: "parcial", title: "Parcial 1",
        term: @active_term.code, score: 5.0, max_score: 5.0, weight: 1.0)
      other_enrollment.assessments.create!(institution: @institution, kind: "parcial", title: "Parcial 1",
        term: @active_term.code, score: 3.0, max_score: 5.0, weight: 1.0)

      result = ReportCards::Computation.call(student: @student, academic_term: @active_term, institution: @institution)

      assert_equal 2, result.lines.size
      assert_equal BigDecimal("4.0"), result.overall_average # (5.0 + 3.0) / 2
    end
  end

  test "only considers enrollments/assessments for the given academic term" do
    within_tenant(@institution) do
      # A student/subject pair enrolls only once ever (unique index on
      # enrollments), so a DIFFERENT subject stands in for "an enrollment
      # that belongs to some other term" here.
      other_term = Core::AcademicTerm.create!(institution: @institution, code: "2025-2", name: "2025-2",
        starts_on: Date.new(2025, 7, 1), ends_on: Date.new(2025, 12, 15), status: "closed")
      other_subject = Schedules::Subject.create!(institution: @institution, name: "Historia", code: "HIS-RC",
        term: other_term.code)
      other_enrollment = Schedules::Enrollment.create!(institution: @institution, student: @student,
        subject: other_subject, term: other_term.code, academic_term: other_term, status: "enrolled")
      other_enrollment.assessments.create!(institution: @institution, kind: "parcial", title: "Viejo",
        term: other_term.code, score: 1.0, max_score: 5.0, weight: 1.0)

      result = ReportCards::Computation.call(student: @student, academic_term: @active_term, institution: @institution)

      assert_empty result.lines
    end
  end
end
