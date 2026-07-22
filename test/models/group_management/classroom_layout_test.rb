require "test_helper"

# Slice 2 (BI_DOCUMENT.md §5.3): the classroom_layouts geometry table and the
# append-only reconfiguration mold. Exercised directly (no HTTP), under the
# tenant GUC so RLS FORCE lets the writes through.
class GroupManagement::ClassroomLayoutTest < ActiveSupport::TestCase
  # Set the tenant GUC on the ambient (non-joinable) fixture transaction — NOT
  # a new nested transaction. That way each create! that trips an exclusion
  # constraint rolls back to its OWN savepoint (Rails' standard behavior in
  # transactional tests) instead of aborting an enclosing joinable transaction,
  # which is what lets assert_raises work here.
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "cl-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_term(institution)
    Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
      starts_on: Date.new(2026, 1, 15), ends_on: Date.new(2026, 6, 15))
  end

  def build_section(institution)
    GroupManagement::Section.create!(institution: institution, name: "9°A", academic_year: 2026)
  end

  test "the DB rejects two overlapping layout versions for the same section+term" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution)
      term = build_term(institution)
      GroupManagement::ClassroomLayout.create!(institution: institution, section: section, academic_term: term,
        rows: 5, cols: 6, version: 1, effective_from: 10.days.ago.to_date)

      assert_raises(ActiveRecord::StatementInvalid) do
        GroupManagement::ClassroomLayout.create!(institution: institution, section: section, academic_term: term,
          rows: 4, cols: 4, version: 2, effective_from: 5.days.ago.to_date)
      end
    end
  end

  test "reconfiguring mid-year closes the current version and opens the next — no overlap violation" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution)
      term = build_term(institution)
      first = GroupManagement::ClassroomReconfigurer.call(section: section, academic_term: term,
        rows: 5, cols: 6, institution: institution).layout
      assert_equal 1, first.version
      assert first.current?

      result = GroupManagement::ClassroomReconfigurer.call(section: section, academic_term: term,
        rows: 4, cols: 5, board_orientation: 90, institution: institution)

      assert_equal 2, result.layout.version
      assert result.layout.current?
      assert_equal 90, result.layout.board_orientation
      assert_equal Date.current, first.reload.effective_until, "the old version must be closed"
      refute first.reload.current?
      assert_equal 1, GroupManagement::ClassroomLayout.where(section_id: section.id).current.count
    end
  end

  test "a different section+term may hold its own concurrent layout" do
    institution = build_institution
    within_tenant(institution) do
      term = build_term(institution)
      a = build_section(institution)
      b = GroupManagement::Section.create!(institution: institution, name: "9°B", academic_year: 2026)

      GroupManagement::ClassroomReconfigurer.call(section: a, academic_term: term, rows: 5, cols: 6, institution: institution)
      assert_nothing_raised do
        GroupManagement::ClassroomReconfigurer.call(section: b, academic_term: term, rows: 5, cols: 6, institution: institution)
      end
    end
  end
end
