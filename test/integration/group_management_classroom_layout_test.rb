require "test_helper"

# Slice 2 (BI_DOCUMENT.md §5.3): the reconfiguration write surface, owned by
# group_management (decision A2), gated by groups.manage. Opening/reconfiguring
# a layout and assigning/freeing seats, plus the DB double-booking guard
# surfaced as a friendly alert (never a 500).
class GroupManagementClassroomLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member
    @term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end
    @section = within_tenant(@institution) { GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026) }
    @ana = within_tenant(@institution) { build_student("GM-ANA") }
    @leo = within_tenant(@institution) { build_student("GM-LEO") }
  end

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_student(code)
    GroupManagement::Student.create!(institution: @institution, first_name: "Est", last_name: code,
      gender: "male", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023,
      status: "active", section: @section)
  end

  def as_manager(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "coordinator", permission_keys: %w[groups.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "groups.manage is required to reach the classroom layout surface" do
    with_grants { get "/group_management/groups/#{@section.id}/classroom_layout"; assert_response :forbidden }
  end

  test "a manager opens a layout, then reconfiguring opens the next version" do
    as_manager do
      get "/group_management/groups/#{@section.id}/classroom_layout"
      assert_response :success

      assert_difference -> { within_tenant(@institution) { GroupManagement::ClassroomLayout.count } }, 1 do
        post "/group_management/groups/#{@section.id}/classroom_layout",
          params: { classroom_layout: { rows: 4, cols: 5, board_orientation: 0 } }
      end
      assert_redirected_to "/group_management/groups/#{@section.id}/classroom_layout"

      # Reconfigure -> version 2, old one closed (still 1 current).
      post "/group_management/groups/#{@section.id}/classroom_layout",
        params: { classroom_layout: { rows: 3, cols: 3, board_orientation: 90 } }
      within_tenant(@institution) do
        assert_equal 2, GroupManagement::ClassroomLayout.where(section_id: @section.id).count
        assert_equal 1, GroupManagement::ClassroomLayout.where(section_id: @section.id).current.count
        assert_equal 2, GroupManagement::ClassroomLayout.where(section_id: @section.id).current.first.version
      end
    end
  end

  test "a manager assigns a seat; double-booking it shows a friendly alert, not a 500" do
    within_tenant(@institution) do
      GroupManagement::ClassroomReconfigurer.call(section: @section, academic_term: @term, rows: 3, cols: 3, institution: @institution)
    end

    as_manager do
      post "/group_management/groups/#{@section.id}/seat_assignments", params: { student_id: @ana.id, row: 0, col: 0 }
      assert_redirected_to "/group_management/groups/#{@section.id}/classroom_layout"

      post "/group_management/groups/#{@section.id}/seat_assignments", params: { student_id: @leo.id, row: 0, col: 0 }
      assert_redirected_to "/group_management/groups/#{@section.id}/classroom_layout"
      follow_redirect!
      assert_match "ya está ocupado", response.body

      within_tenant(@institution) do
        active = GroupManagement::SeatAssignment.where(institution_id: @institution.id).active
        assert_equal 1, active.count
        assert_equal @ana.id, active.first.student_id
      end
    end
  end

  test "a manager frees a seat (append-only close, row survives)" do
    layout = within_tenant(@institution) do
      GroupManagement::ClassroomReconfigurer.call(section: @section, academic_term: @term, rows: 3, cols: 3, institution: @institution).layout
    end
    within_tenant(@institution) { GroupManagement::SeatAssigner.call(layout: layout, student: @ana, row: 1, col: 1, institution: @institution) }

    as_manager do
      delete "/group_management/groups/#{@section.id}/seat_assignments/#{@ana.id}"
      assert_redirected_to "/group_management/groups/#{@section.id}/classroom_layout"
    end

    within_tenant(@institution) do
      scope = GroupManagement::SeatAssignment.where(classroom_layout_id: layout.id, student_id: @ana.id)
      assert_equal 0, scope.active.count
      assert_equal 1, scope.count, "the freed seat survives as history"
    end
  end
end
