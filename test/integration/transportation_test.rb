require "test_helper"

class TransportationTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_member }
  # :route has no real scope_route_id column in role_assignments (P1 only
  # made department/grade_level/group real — see test_helper.rb's
  # with_raw_grants), so this whole file uses the raw-context override
  # instead of grant_role!'s real seeding.
  def with_grants(*assignments, &block)
    with_raw_grants(*assignments, &block)
  end

  def as_transport_coordinator(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "transport_coordinator", permission_keys: %w[routes.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # A driver scoped to exactly ONE route via the new :route scope dimension.
  def as_driver_route1(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "driver", permission_keys: %w[boarding.manage],
                                     scope_type: :route, scope_id: "route-1"),
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
      get "/transportation/routes/route-1"
      assert_response :forbidden # boarding.manage grants nothing for routes.view
    end
  end

  test "boarding shows only the driver's own route, via the :route scope" do
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

  test "boarding_events#create is scoped to the driver's own route" do
    as_driver_route1 do
      post "/transportation/boarding_events", params: { route_id: "route-1", student_id: "s-1", status_label: "abordaje" }
      assert_redirected_to transportation_boarding_path

      post "/transportation/boarding_events", params: { route_id: "route-3", student_id: "s-4", status_label: "abordaje" }
      assert_response :forbidden
    end
  end

  # --- portals: resolved by relation, no RBAC permission needed at all ------

  test "student portal transport renders with no grants" do
    with_grants do
      get "/portal/student/transport"
      assert_response :success
      assert_select "dd", text: "Ruta 3"
    end
  end

  test "guardian portal transport renders both children's routes with no grants" do
    with_grants do
      get "/portal/guardian/transport"
      assert_response :success
      assert_select "h3", text: "Ana Martínez"
      assert_select "h3", text: "Luis Martínez"
    end
  end

  # --- staff_management: closes the Fase 0 orphaned nav ----------------------

  test "staff directory works for the default demo persona (already holds staff.read)" do
    get "/staff_management/staff"
    assert_response :success
    assert_select ".staff-row__person", text: /Rosa Elena Duarte/
  end

  test "staff directory denies an actor without staff.read" do
    with_grants { get "/staff_management/staff"; assert_response :forbidden }
  end
end
