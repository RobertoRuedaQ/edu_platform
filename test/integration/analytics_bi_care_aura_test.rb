require "test_helper"

# Slice 3 security acceptance (BI_DOCUMENT.md §12, Class S) — the TEACHER side
# of Lens 5. Same spirit as the María/teacher_management case (PROJECT_STATE.md
# §6.4), driven end-to-end through the seat-grid controller:
#   * hps.aura.view (the SECOND permission) is required to see the aura badge;
#     hps.classroom.view alone renders the plain Slice-2 grid unchanged.
#   * the teacher sees ONLY the abstract projection (kind label + guidance),
#     never anything from counseling.
#   * scope + institution isolation hold (403 out of scope, 404 cross-tenant).
#   * NO code path in the teacher's request touches counseling_cases/
#     session_notes/referrals (asserted via a live SQL tap on the request).
class AnalyticsBiCareAuraTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member
    within_tenant(@institution) do
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section_a = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @section_b = GroupManagement::Section.create!(institution: @institution, name: "9°B", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "Pérez",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "AR-ANA", entry_year: 2023,
        status: "active", section: @section_a)
      layout = GroupManagement::ClassroomReconfigurer.call(section: @section_a, academic_term: @term,
        rows: 2, cols: 2, institution: @institution).layout
      GroupManagement::SeatAssigner.call(layout: layout, student: @student, row: 0, col: 0, institution: @institution)
      GroupManagement::ClassroomReconfigurer.call(section: @section_b, academic_term: @term,
        rows: 2, cols: 2, institution: @institution)
      counselor = @institution.memberships.active.find_by!(user: @user)
      AnalyticsBi::Aura::Projector.call(student: @student, academic_term: @term, aura_kind: "extra_time",
        guidance_text: "Concede tiempo adicional en las entregas.", authored_by: counselor, institution: @institution)
    end
  end

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def as_viewer(permission_keys:, scope_type: :institution, scope_id: nil, &block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: permission_keys,
        scope_type: scope_type, scope_id: scope_id),
      &block
    )
  end

  test "hps.aura.view surfaces the abstract aura badge (kind label + guidance) on the seat grid" do
    as_viewer(permission_keys: %w[hps.classroom.view hps.aura.view]) do
      get "/analytics_bi/spatial_classrooms/#{@section_a.id}"
      assert_response :success
      assert_select "svg.seat-grid__svg"
      assert_match "AP", response.body                                   # Slice 2 initials still there
      assert_match "Tiempo adicional", response.body                     # the enum's human label
      assert_match "Concede tiempo adicional en las entregas", response.body # the counselor's guidance
      assert_select "g.seat__aura"                                       # the discrete badge
    end
  end

  test "hps.classroom.view WITHOUT hps.aura.view renders the plain grid, no aura leak" do
    as_viewer(permission_keys: %w[hps.classroom.view]) do
      get "/analytics_bi/spatial_classrooms/#{@section_a.id}"
      assert_response :success
      assert_select "svg.seat-grid__svg"
      assert_select "g.seat__aura", count: 0
      assert_no_match(/Tiempo adicional/, response.body)
      assert_no_match(/Concede tiempo adicional/, response.body)
    end
  end

  test "the teacher's aura request never touches any counseling table" do
    as_viewer(permission_keys: %w[hps.classroom.view hps.aura.view]) do
      queries = []
      callback = lambda do |_n, _s, _f, _id, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get "/analytics_bi/spatial_classrooms/#{@section_a.id}"
      end
      assert_response :success

      offenders = queries.select { |sql| sql.match?(/counseling_cases|session_notes|referrals/) }
      assert offenders.empty?, "teacher request touched counseling tables: #{offenders.inspect}"
      assert queries.any? { |sql| sql.include?("care_auras") }, "expected the projection to be read"
    end
  end

  test "a group-scoped viewer is forbidden from a classroom outside their scope" do
    as_viewer(permission_keys: %w[hps.classroom.view hps.aura.view], scope_type: :group, scope_id: @section_a.id) do
      get "/analytics_bi/spatial_classrooms/#{@section_b.id}"
      assert_response :forbidden

      get "/analytics_bi/spatial_classrooms/#{@section_a.id}"
      assert_response :success
      assert_match "Tiempo adicional", response.body
    end
  end

  test "an aura for a student in another institution is never reachable (404, no leak)" do
    other = Core::Institution.create!(name: "Otro", slug: "otro-#{SecureRandom.hex(3)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    foreign_section = within_tenant(other) do
      GroupManagement::Section.create!(institution: other, name: "X", academic_year: 2026)
    end

    as_viewer(permission_keys: %w[hps.classroom.view hps.aura.view]) do
      get "/analytics_bi/spatial_classrooms/#{foreign_section.id}"
      assert_response :not_found
    end
  end
end
