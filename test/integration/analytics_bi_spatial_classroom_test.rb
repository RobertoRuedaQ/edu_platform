require "test_helper"

# Slice 2 acceptance (BI_DOCUMENT.md §12): Lens 1 is a SUPERVISION surface —
# authorize!("hps.classroom.view") + scope actually gate WHO sees WHICH
# classroom, in the same spirit as the María/teacher_management case
# (PROJECT_STATE.md §6.4). Driven end-to-end through the controller.
class AnalyticsBiSpatialClassroomTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member
    @term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end
    @section_a = within_tenant(@institution) { GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026) }
    @section_b = within_tenant(@institution) { GroupManagement::Section.create!(institution: @institution, name: "9°B", academic_year: 2026) }
    within_tenant(@institution) do
      layout_a = GroupManagement::ClassroomReconfigurer.call(section: @section_a, academic_term: @term,
        rows: 3, cols: 3, institution: @institution).layout
      GroupManagement::ClassroomReconfigurer.call(section: @section_b, academic_term: @term,
        rows: 3, cols: 3, institution: @institution)
      student = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "P",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "SC-ANA", entry_year: 2023, status: "active")
      GroupManagement::SeatAssigner.call(layout: layout_a, student: student, row: 0, col: 0, institution: @institution)
    end
  end

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def as_classroom_viewer(scope_type: :institution, scope_id: nil, &block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[hps.classroom.view],
                                     scope_type: scope_type, scope_id: scope_id),
      &block
    )
  end

  test "hps.classroom.view is required to see the spatial map at all" do
    with_grants { get "/analytics_bi/spatial_classrooms"; assert_response :forbidden }

    as_classroom_viewer do
      get "/analytics_bi/spatial_classrooms"
      assert_response :success
      assert_match "9°A", response.body
      assert_match "9°B", response.body
    end
  end

  test "a group-scoped observer sees ONLY their own classroom in the index" do
    as_classroom_viewer(scope_type: :group, scope_id: @section_a.id) do
      get "/analytics_bi/spatial_classrooms"
      assert_response :success
      assert_match "9°A", response.body
      assert_no_match(/9°B/, response.body)
    end
  end

  test "a group-scoped observer is forbidden from a classroom outside their scope" do
    as_classroom_viewer(scope_type: :group, scope_id: @section_a.id) do
      get "/analytics_bi/spatial_classrooms/#{@section_b.id}"
      assert_response :forbidden

      get "/analytics_bi/spatial_classrooms/#{@section_a.id}"
      assert_response :success
      assert_select "svg.seat-grid__svg"
      assert_match "AP", response.body # Ana P.'s server-rendered initials
    end
  end

  test "a section from another institution is never reachable (404, not a cross-tenant leak)" do
    other = Core::Institution.create!(name: "Otro", slug: "otro-#{SecureRandom.hex(3)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    foreign_section = within_tenant(other) { GroupManagement::Section.create!(institution: other, name: "X", academic_year: 2026) }

    as_classroom_viewer do
      get "/analytics_bi/spatial_classrooms/#{foreign_section.id}"
      assert_response :not_found
    end
  end

  test "the default demo persona never sees the Mapa del aula nav tile" do
    get "/"
    assert_response :success
    assert_select "a.tile", text: /Mapa del aula/, count: 0
  end

  test "hps.classroom.view (read) never implies groups.manage (reconfigure write)" do
    as_classroom_viewer do
      get "/group_management/groups/#{@section_a.id}/classroom_layout"
      assert_response :forbidden
    end
  end
end
