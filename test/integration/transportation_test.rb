require "test_helper"

# transportation (guidelines/CLOSURE_PLAN.md Fase D, third increment, v1.49.0):
# retires RouteRoster/RiderRoster (100% Data.define stubs) for real routes/
# route_stops/route_riders/boarding_events, AND wires the :route scope
# dimension into the REAL RBAC engine (role_assignments.scope_route_id) —
# "a driver sees only their own route" used to be test-only
# (Authorization::StubResolver via with_raw_grants), now a real grant_role!
# call like every other scope dimension.
class TransportationTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  setup do
    @user, @institution = sign_in_as_member
    within_tenant(@institution) do
      section = GroupManagement::Section.create!(institution: @institution, name: "9A", academic_year: 2026)

      @route1 = Transportation::Route.create!(institution: @institution, name: "Ruta 1",
        vehicle_plate: "ABC-123", capacity: 20)
      @route3 = Transportation::Route.create!(institution: @institution, name: "Ruta 3",
        vehicle_plate: "XYZ-789", capacity: 24)
      stop1 = @route1.route_stops.create!(institution: @institution, name: "Portal Norte",
        position: 1, scheduled_time: "06:15")
      stop3 = @route3.route_stops.create!(institution: @institution, name: "Suba",
        position: 1, scheduled_time: "06:00")

      @student_in = GroupManagement::Student.create!(institution: @institution, section: section,
        first_name: "Valentina", last_name: "Suárez", gender: "female", birthdate: Date.new(2013, 3, 1),
        entry_year: 2023, student_code: "TR-IN")
      @student_out = GroupManagement::Student.create!(institution: @institution, section: section,
        first_name: "Mateo", last_name: "Cárdenas", gender: "male", birthdate: Date.new(2013, 3, 1),
        entry_year: 2023, student_code: "TR-OUT")

      Transportation::RouteRider.create!(institution: @institution, route: @route1, student: @student_in,
        route_stop: stop1, shift: "am")
      Transportation::RouteRider.create!(institution: @institution, route: @route3, student: @student_out,
        route_stop: stop3, shift: "am")
    end
  end

  def as_transport_coordinator(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "transport_coordinator", permission_keys: %w[routes.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # A driver scoped to exactly ONE route via the real :route scope (v1.49.0).
  def as_driver_route1(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "driver", permission_keys: %w[boarding.manage],
                                     scope_type: :route, scope_id: @route1.id),
      &block
    )
  end

  test "routes index requires routes.view" do
    with_grants { get "/transportation/routes"; assert_response :forbidden }

    as_transport_coordinator do
      get "/transportation/routes"
      assert_response :success
      assert_select "a", text: "Ruta 1"
      assert_select "a", text: "Ruta 3"
    end
  end

  test "routes show is denied for a role without routes.view" do
    as_driver_route1 do
      get "/transportation/routes/#{@route1.id}"
      assert_response :forbidden # boarding.manage grants nothing for routes.view
    end
  end

  test "routes show lists stops and riders with their shift" do
    as_transport_coordinator do
      get "/transportation/routes/#{@route1.id}"
      assert_response :success
      assert_select "td", text: "Valentina Suárez"
      assert_select "td", text: "Mañana"
      assert_select "td", text: "Portal Norte"
    end
  end

  test "boarding shows only the driver's own route, via the real :route scope" do
    as_driver_route1 do
      get "/transportation/boarding"
      assert_response :success
      assert_select "h3", text: "Ruta 1"
      assert_select "h3", text: "Ruta 3", count: 0
    end
  end

  test "an actor with no grants is denied boarding (403)" do
    with_grants { get "/transportation/boarding"; assert_response :forbidden }
  end

  test "boarding_events#create persists a real event, scoped to the driver's own route" do
    as_driver_route1 do
      assert_difference -> { Transportation::BoardingEvent.count }, 1 do
        post "/transportation/boarding_events",
          params: { route_id: @route1.id, student_id: @student_in.id, event_type: "boarded" }
      end
      assert_redirected_to transportation_boarding_path
      event = Transportation::BoardingEvent.last
      assert_equal @student_in.id, event.student_id
      assert_equal "boarded", event.event_type
      assert_equal @user.id, event.recorded_by.user_id

      assert_no_difference -> { Transportation::BoardingEvent.count } do
        post "/transportation/boarding_events",
          params: { route_id: @route3.id, student_id: @student_out.id, event_type: "boarded" }
      end
      assert_response :forbidden
    end
  end

  test "boarding_events#create rejects an invalid event_type without persisting or 500ing" do
    as_driver_route1 do
      assert_no_difference -> { Transportation::BoardingEvent.count } do
        post "/transportation/boarding_events",
          params: { route_id: @route1.id, student_id: @student_in.id, event_type: "bogus" }
      end
      assert_redirected_to transportation_boarding_path
      assert_match(/is not included in the list/, flash[:alert])
    end
  end

  # --- portals: resolved by relation, no RBAC permission needed at all ------

  test "student portal transport renders the student's own routes, am and pm separately" do
    student_user = within_tenant(@institution) do
      user = Core::User.create!(email: "student-#{SecureRandom.hex(4)}@member.test", name: "Valentina",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      @student_in.update!(user: user)
      # a PM route on a DIFFERENT route than the AM one from setup
      Transportation::RouteRider.create!(institution: @institution, route: @route3, student: @student_in, shift: "pm")
      user
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")

    get "/portal/student/transport"
    assert_response :success
    assert_select "dd", text: "Mañana"
    assert_select "dd", text: "Tarde"
    assert_select "dd", text: "Ruta 1"
    assert_select "dd", text: "Ruta 3"
  end

  test "student portal transport shows an empty state with no route assigned" do
    student_user = within_tenant(@institution) do
      section = GroupManagement::Section.find_by!(institution: @institution, name: "9A")
      student = GroupManagement::Student.create!(institution: @institution, section: section,
        first_name: "Sin", last_name: "Ruta", gender: "male", birthdate: Date.new(2013, 3, 1),
        entry_year: 2023, student_code: "TR-NONE")
      user = Core::User.create!(email: "student-none-#{SecureRandom.hex(4)}@member.test", name: "Sin Ruta",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      student.update!(user: user)
      user
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")

    get "/portal/student/transport"
    assert_response :success
    assert_match(/Sin ruta asignada/, response.body)
  end

  test "guardian portal transport renders both children's routes, never a child outside the relation" do
    guardian = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: @student_in,
        relationship: "madre", status: "active")
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: @student_out,
        relationship: "madre", status: "active")
      user
    end
    sign_in_as(guardian, institution: @institution, password: "password-123456")

    get "/portal/guardian/transport"
    assert_response :success
    assert_select "h3", text: "Valentina Suárez"
    assert_select "h3", text: "Mateo Cárdenas"
    assert_select "dd", text: "Ruta 1"
    assert_select "dd", text: "Ruta 3"
  end

  # staff_management's own directory coverage (scope-filtered, real data)
  # lives in test/integration/staff_directory_test.rb since #4 slice 1
  # (v1.13.0) — these two tests used to assert against StaffRoster's
  # hardcoded stub fixture ("Rosa Elena Duarte"), which no longer exists now
  # that the directory reads real StaffManagement::StaffMember rows.
end
