require "test_helper"

class CafeteriaTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_member } # auth is now required app-wide; persona still from StubAssignments
  def with_grants(*assignments)
    original = Authorization::StubAssignments.method(:all)
    Authorization::StubAssignments.define_singleton_method(:all) { assignments }
    yield
  ensure
    Authorization::StubAssignments.define_singleton_method(:all, original)
  end

  def as_cafeteria_staff(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "cafeteria_staff", permission_keys: %w[menu.view checkout.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_treasury(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "treasury", permission_keys: %w[finance.read],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "menu index requires menu.view" do
    with_grants { get "/cafeteria/menu"; assert_response :forbidden }

    as_cafeteria_staff do
      get "/cafeteria/menu"
      assert_response :success
      assert_select ".menu-item__name", text: "Arroz con pollo"
    end
  end

  test "can? shows Saldos/Nuevo checkout only for the matching permission" do
    as_cafeteria_staff do
      get "/cafeteria/menu"
      assert_select "a.btn", text: "Nuevo checkout"
      assert_select "a.btn", text: "Saldos", count: 0 # cafeteria_staff lacks finance.read
    end

    as_treasury do
      get "/cafeteria/menu"
      assert_response :forbidden # treasury lacks menu.view entirely
    end
  end

  test "checkout new reflects the allergen block for a student with a matching allergy" do
    as_cafeteria_staff do
      get "/cafeteria/checkouts/new", params: { student_id: "s-1" } # s-1 has alergia_mani
      assert_response :success

      assert_select ".checkout-line.is-blocked .checkout-line__name", text: "Sándwich de mantequilla de maní"
      assert_select ".checkout-line__name", text: "Arroz con pollo" # not blocked, no is-blocked ancestor
      assert_select ".checkout-line:not(.is-blocked) .checkout-line__name", text: "Arroz con pollo"
    end
  end

  test "create refuses the sale server-side when a blocked item is submitted, even directly" do
    as_cafeteria_staff do
      post "/cafeteria/checkouts", params: { student_id: "s-1", item_ids: [ "menu-2" ] } # blocked: alergia_mani
      assert_response :unprocessable_entity
      assert_select ".alert--danger", text: /bloqueada/
    end
  end

  test "create completes the sale for items with no matching allergen" do
    as_cafeteria_staff do
      post "/cafeteria/checkouts", params: { student_id: "s-1", item_ids: [ "menu-1" ] } # Arroz con pollo, safe
      assert_redirected_to cafeteria_menu_path
      follow_redirect!
      assert_match "Compra registrada", flash[:notice].to_s
    end
  end

  test "checkout is denied entirely without checkout.manage" do
    with_grants(
      Authorization::Assignment.new(role_key: "menu_reader", permission_keys: %w[menu.view],
                                     scope_type: :institution, scope_id: nil)
    ) do
      get "/cafeteria/checkouts/new"
      assert_response :forbidden
    end
  end

  test "balances index requires finance.read, not menu.view" do
    as_cafeteria_staff { get "/cafeteria/balances"; assert_response :forbidden }

    as_treasury do
      get "/cafeteria/balances"
      assert_response :success
      assert_select "td", text: "9°A"
    end
  end

  # --- portals: resolved by relation, no RBAC permission needed at all ------

  test "student portal cafeteria renders the stub balance with no grants" do
    with_grants do
      get "/portal/student/cafeteria"
      assert_response :success
      assert_select ".stat__value", text: "$24.500"
    end
  end

  test "guardian portal cafeteria renders both children's balances with no grants" do
    with_grants do
      get "/portal/guardian/cafeteria"
      assert_response :success
      assert_select ".stat__label", text: /Ana Martínez/
      assert_select ".stat__label", text: /Luis Martínez/
    end
  end
end
