require "test_helper"

# Slice 2 (BI_DOCUMENT.md §5.3): the seat_assignments table's two GiST
# exclusion constraints and the append-only "move a student" mold. Exercised
# directly under the tenant GUC (RLS FORCE).
class GroupManagement::SeatAssignmentTest < ActiveSupport::TestCase
  # See ClassroomLayoutTest: set the GUC on the ambient fixture transaction so
  # exclusion-constraint violations roll back to their own savepoint and
  # assert_raises works, instead of aborting a nested joinable transaction.
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "sa-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_term(institution)
    Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
      starts_on: Date.new(2026, 1, 15), ends_on: Date.new(2026, 6, 15))
  end

  def build_section(institution)
    GroupManagement::Section.create!(institution: institution, name: "9°A", academic_year: 2026)
  end

  def build_student(institution, code)
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023, status: "active")
  end

  def build_layout(institution, section, term)
    GroupManagement::ClassroomLayout.create!(institution: institution, section: section, academic_term: term,
      rows: 5, cols: 6, version: 1, effective_from: 30.days.ago.to_date)
  end

  test "assigning a free seat succeeds; double-booking the same seat raises" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution)
      term = build_term(institution)
      layout = build_layout(institution, section, term)
      ana = build_student(institution, "SA-ANA")
      leo = build_student(institution, "SA-LEO")

      GroupManagement::SeatAssigner.call(layout: layout, student: ana, row: 0, col: 0, institution: institution)

      assert_raises(ActiveRecord::StatementInvalid) do
        GroupManagement::SeatAssigner.call(layout: layout, student: leo, row: 0, col: 0, institution: institution)
      end
    end
  end

  test "the DB forbids a single student holding two active seats at once" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution)
      term = build_term(institution)
      layout = build_layout(institution, section, term)
      ana = build_student(institution, "SA-ANA")

      GroupManagement::SeatAssignment.create!(institution: institution, classroom_layout: layout, student: ana,
        row: 0, col: 0, effective_from: Date.current)

      # Bypassing SeatAssigner (which would close the first) proves the DB
      # constraint itself, not just the service discipline.
      assert_raises(ActiveRecord::StatementInvalid) do
        GroupManagement::SeatAssignment.create!(institution: institution, classroom_layout: layout, student: ana,
          row: 2, col: 2, effective_from: Date.current)
      end
    end
  end

  test "moving a student closes the old seat and opens a new one — no violation, history preserved" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution)
      term = build_term(institution)
      layout = build_layout(institution, section, term)
      ana = build_student(institution, "SA-ANA")

      GroupManagement::SeatAssigner.call(layout: layout, student: ana, row: 0, col: 0, institution: institution)
      assert_nothing_raised do
        GroupManagement::SeatAssigner.call(layout: layout, student: ana, row: 1, col: 1, institution: institution)
      end

      seats = GroupManagement::SeatAssignment.where(classroom_layout_id: layout.id, student_id: ana.id).order(:effective_from, :row)
      assert_equal 2, seats.count, "the old seat is kept as history, never overwritten"
      active = seats.select(&:active?)
      assert_equal 1, active.size
      assert_equal [ 1, 1 ], [ active.first.row, active.first.col ]

      # Freeing the seat leaves the row (append-only), just closes it.
      GroupManagement::SeatAssigner.unassign(layout: layout, student: ana, institution: institution)
      assert_equal 0, GroupManagement::SeatAssignment.where(classroom_layout_id: layout.id, student_id: ana.id).active.count
      assert_equal 2, GroupManagement::SeatAssignment.where(classroom_layout_id: layout.id, student_id: ana.id).count
    end
  end
end
