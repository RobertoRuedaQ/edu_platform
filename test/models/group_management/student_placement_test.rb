require "test_helper"

# Slice 4 (BI_DOCUMENT.md §5.2): the student_placements GiST exclusion
# constraint, the append-only "reassign a student" mold (SectionReassigner), and
# the backfill correctness (PlacementBackfill). Exercised directly under the
# tenant GUC (RLS FORCE).
class GroupManagement::StudentPlacementTest < ActiveSupport::TestCase
  # Set the GUC on the ambient fixture transaction (NOT a nested joinable
  # transaction) so an exclusion-constraint violation rolls back to its own
  # savepoint and assert_raises works — same idiom as SeatAssignmentTest.
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "sp-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_term(institution)
    Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
      starts_on: Date.new(2026, 1, 15), ends_on: Date.new(2026, 12, 15))
  end

  def build_grade(institution)
    GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
  end

  def build_section(institution, grade, name)
    GroupManagement::Section.create!(institution: institution, grade_level: grade, name: name, academic_year: 2026)
  end

  def build_student(institution, grade, section, code)
    GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
      first_name: "Est", last_name: code, gender: "female", birthdate: Date.new(2013, 3, 1),
      student_code: code, entry_year: 2023, status: "active")
  end

  test "the DB forbids two overlapping active placements for the same student" do
    institution = build_institution
    within_tenant(institution) do
      term = build_term(institution)
      grade = build_grade(institution)
      section = build_section(institution, grade, "9°A")
      ana = build_student(institution, grade, section, "SP-ANA")

      GroupManagement::StudentPlacement.create!(institution: institution, student: ana, section: section,
        grade_level: grade, academic_term: term, valid_from: Date.current)

      # Bypassing SectionReassigner (which would close the first) proves the DB
      # constraint itself, not just the service discipline.
      assert_raises(ActiveRecord::StatementInvalid) do
        GroupManagement::StudentPlacement.create!(institution: institution, student: ana, section: section,
          grade_level: grade, academic_term: term, valid_from: Date.current)
      end
    end
  end

  test "moving a student between sections closes the old placement and opens a new one — no gap, no overlap" do
    institution = build_institution
    within_tenant(institution) do
      build_term(institution)
      grade = build_grade(institution)
      section_a = build_section(institution, grade, "9°A")
      section_b = build_section(institution, grade, "9°B")
      ana = build_student(institution, grade, section_a, "SP-ANA")

      GroupManagement::SectionReassigner.call(student: ana, section: section_a, institution: institution)
      assert_nothing_raised do
        GroupManagement::SectionReassigner.call(student: ana, section: section_b, institution: institution)
      end

      placements = GroupManagement::StudentPlacement.where(student_id: ana.id).order(:valid_from, :created_at)
      assert_equal 2, placements.count, "the old placement is kept as history, never overwritten"
      active = placements.select(&:current?)
      assert_equal 1, active.size, "exactly one open placement"
      assert_equal section_b.id, active.first.section_id
      # Adjacent ranges: [from, today) and [today, ∞) — the closed one ends the
      # same day the open one starts, so there is no coverage gap.
      closed = placements.reject(&:current?).first
      assert_equal Date.current, closed.valid_until
      assert_equal section_a.id, closed.section_id

      # section_id cache stays in lock-step with the open placement.
      assert_equal section_b.id, ana.reload.section_id
    end
  end

  test "unassigning (section: nil) closes the placement without opening a new one and nils the cache" do
    institution = build_institution
    within_tenant(institution) do
      build_term(institution)
      grade = build_grade(institution)
      section = build_section(institution, grade, "9°A")
      ana = build_student(institution, grade, section, "SP-ANA")

      GroupManagement::SectionReassigner.call(student: ana, section: section, institution: institution)
      GroupManagement::SectionReassigner.call(student: ana, section: nil, institution: institution)

      assert_equal 0, GroupManagement::StudentPlacement.where(student_id: ana.id).current.count
      assert_equal 1, GroupManagement::StudentPlacement.where(student_id: ana.id).count, "history preserved"
      assert_nil ana.reload.section_id
    end
  end

  test "reassigning to the same section with a matching open placement is a no-op (idempotent)" do
    institution = build_institution
    within_tenant(institution) do
      build_term(institution)
      grade = build_grade(institution)
      section = build_section(institution, grade, "9°A")
      ana = build_student(institution, grade, section, "SP-ANA")

      GroupManagement::SectionReassigner.call(student: ana, section: section, institution: institution)
      GroupManagement::SectionReassigner.call(student: ana, section: section, institution: institution)

      assert_equal 1, GroupManagement::StudentPlacement.where(student_id: ana.id).count,
        "a resubmit of the same roster never churns placement history"
    end
  end

  test "backfill creates exactly one open placement per active, placed student and is idempotent" do
    institution = build_institution
    within_tenant(institution) do
      build_term(institution)
      grade = build_grade(institution)
      section = build_section(institution, grade, "9°A")
      ana = build_student(institution, grade, section, "SP-ANA")
      leo = build_student(institution, grade, section, "SP-LEO")
      # Placed but withdrawn -> not active -> skipped.
      _gone = GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
        first_name: "Est", last_name: "GONE", gender: "male", birthdate: Date.new(2013, 3, 1),
        student_code: "SP-GONE", entry_year: 2023, status: "withdrawn")
      # Active but unplaced (no section) -> skipped.
      _unplaced = GroupManagement::Student.create!(institution: institution, grade_level: grade,
        first_name: "Est", last_name: "NOSEC", gender: "male", birthdate: Date.new(2013, 3, 1),
        student_code: "SP-NOSEC", entry_year: 2023, status: "active")

      result = GroupManagement::PlacementBackfill.run(institution: institution)
      assert_equal 2, result.placed
      assert_equal 1, result.skipped, "the active, unplaced student is skipped (withdrawn is not counted at all)"

      [ ana, leo ].each do |student|
        open = GroupManagement::StudentPlacement.where(student_id: student.id).current
        assert_equal 1, open.count, "exactly one open placement per active placed student"
        assert_equal section.id, open.first.section_id
      end

      # Re-run: every student already has a matching open placement -> no churn.
      GroupManagement::PlacementBackfill.run(institution: institution)
      assert_equal 2, GroupManagement::StudentPlacement.where(student_id: [ ana.id, leo.id ]).count,
        "re-running the backfill never duplicates placements"
    end
  end
end
