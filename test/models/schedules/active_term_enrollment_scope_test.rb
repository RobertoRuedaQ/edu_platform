require "test_helper"

# Schedules::ActiveTermEnrollmentScope (v1.15.0) — THE canonical resolver for
# "the student enrolled in the active term", closing the model half of
# Cav./B2. Every academic slice that follows (attendance, notas-por-término,
# actividades, asignaciones) is meant to consume this.
class Schedules::ActiveTermEnrollmentScopeTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "ates-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_term!(institution, code:, status:)
    Core::AcademicTerm.create!(institution: institution, code: code, name: code,
      starts_on: Date.new(2025, 1, 1), ends_on: Date.new(2025, 6, 30), status: status)
  end

  def build_student!(institution, code:)
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2012, 1, 1), student_code: code, entry_year: 2023)
  end

  def build_subject!(institution, term:)
    Schedules::Subject.create!(institution: institution, name: "Álgebra", code: "MAT-#{SecureRandom.hex(2)}", term: term)
  end

  def enroll!(institution, student:, subject:, academic_term:)
    Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      term: subject.term, academic_term: academic_term, status: "enrolled")
  end

  test "resolves a student enrolled in the active term" do
    institution = build_institution

    within_tenant(institution) do
      active_term = build_term!(institution, code: "2026-1", status: "active")
      subject = build_subject!(institution, term: "2026-1")
      student = build_student!(institution, code: "A1")
      enroll!(institution, student: student, subject: subject, academic_term: active_term)

      result = Schedules::ActiveTermEnrollmentScope.resolve(institution: institution)
      assert_equal [ student.id ], result.pluck(:id)
    end
  end

  test "excludes a student enrolled only in a past (non-active) term" do
    institution = build_institution

    within_tenant(institution) do
      build_term!(institution, code: "2026-1", status: "active")
      past_term = build_term!(institution, code: "2025-2", status: "closed")
      subject = build_subject!(institution, term: "2025-2")
      student = build_student!(institution, code: "PAST")
      enroll!(institution, student: student, subject: subject, academic_term: past_term)

      result = Schedules::ActiveTermEnrollmentScope.resolve(institution: institution)
      assert_empty result
    end
  end

  test "excludes a student with no term enrollment at all" do
    institution = build_institution

    within_tenant(institution) do
      build_term!(institution, code: "2026-1", status: "active")
      build_student!(institution, code: "NONE")

      result = Schedules::ActiveTermEnrollmentScope.resolve(institution: institution)
      assert_empty result
    end
  end

  test "excludes a student whose enrollment predates this column (academic_term_id nil, legacy term string only)" do
    institution = build_institution

    within_tenant(institution) do
      build_term!(institution, code: "2026-1", status: "active")
      subject = build_subject!(institution, term: "2026-1")
      student = build_student!(institution, code: "LEGACY")
      Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
        term: "2026-1", academic_term: nil, status: "enrolled")

      result = Schedules::ActiveTermEnrollmentScope.resolve(institution: institution)
      assert_empty result, "a legacy enrollment (nil academic_term_id) must not be treated as a real term match"
    end
  end

  test "returns an empty relation when the institution has no active term at all" do
    institution = build_institution

    within_tenant(institution) do
      build_term!(institution, code: "2025-2", status: "closed")

      result = Schedules::ActiveTermEnrollmentScope.resolve(institution: institution)
      assert_empty result
    end
  end

  test "never returns a student from a DIFFERENT institution" do
    institution_i = build_institution
    institution_j = build_institution

    within_tenant(institution_j) do
      term_j = build_term!(institution_j, code: "2026-1", status: "active")
      subject_j = build_subject!(institution_j, term: "2026-1")
      student_j = build_student!(institution_j, code: "CROSS")
      enroll!(institution_j, student: student_j, subject: subject_j, academic_term: term_j)
    end

    within_tenant(institution_i) do
      build_term!(institution_i, code: "2026-1", status: "active")

      result = Schedules::ActiveTermEnrollmentScope.resolve(institution: institution_i)
      assert_empty result, "an enrollment from institution J leaked while acting in institution I"
    end
  end

  test "returns a composable ActiveRecord::Relation" do
    institution = build_institution
    within_tenant(institution) do
      build_term!(institution, code: "2026-1", status: "active")
      assert_kind_of ActiveRecord::Relation, Schedules::ActiveTermEnrollmentScope.resolve(institution: institution)
    end
  end

  test "accepts no search term — the interface itself has no such parameter" do
    accepted_keywords = Schedules::ActiveTermEnrollmentScope.method(:resolve).parameters.map(&:last)
    assert_not_includes accepted_keywords, :q
    assert_not_includes accepted_keywords, :term
    assert_not_includes accepted_keywords, :search
  end
end
