require "test_helper"

class CafeteriaTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  # Same 5 items the retired MenuRoster stub carried (db/seeds.rb::MENU_ITEMS),
  # now real Cafeteria::MenuItem rows scoped to @institution.
  def build_menu_items(institution)
    within_tenant(institution) do
      {
        "Arroz con pollo" => Cafeteria::MenuItem.create!(institution: institution, name: "Arroz con pollo",
          category: "Almuerzo", price_cents: 950_000),
        "Sándwich de mantequilla de maní" => Cafeteria::MenuItem.create!(institution: institution,
          name: "Sándwich de mantequilla de maní", category: "Snack", price_cents: 450_000, allergens: [ "Maní" ]),
        "Yogurt con granola" => Cafeteria::MenuItem.create!(institution: institution, name: "Yogurt con granola",
          category: "Snack", price_cents: 380_000, allergens: [ "Lactosa" ], dietary_tags: [ "Vegetariano" ])
      }
    end
  end

  setup do
    @user, @institution = sign_in_as_member
    @menu = build_menu_items(@institution)
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

  # Cafeteria::DietaryRestriction is real (seeded via db/seeds.rb since day
  # one); only CheckoutsController read a parallel STUB until guidelines/
  # CLOSURE_PLAN.md Fase D wired the real model in. These build a real
  # student + a real restriction row instead of the old stub's fake "s-1".
  def build_student_with_allergy(restriction_type: "alergia_mani")
    within_tenant(@institution) do
      grade = GroupManagement::GradeLevel.create!(institution: @institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: @institution, grade_level: grade, name: "9A", academic_year: 2026)
      student = GroupManagement::Student.create!(institution: @institution, grade_level: grade, section: section,
        first_name: "Ana", last_name: "P", gender: "female", birthdate: Date.new(2013, 3, 1),
        student_code: "CAF-#{SecureRandom.hex(3)}", entry_year: 2023, status: "active")
      Cafeteria::DietaryRestriction.create!(institution: @institution, student: student,
        restriction_type: restriction_type, severity: "severa")
      student
    end
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

  test "checkout new reflects the allergen block for a student with a matching REAL allergy" do
    student = build_student_with_allergy(restriction_type: "alergia_mani")

    as_cafeteria_staff do
      get "/cafeteria/checkouts/new", params: { student_id: student.student_code }
      assert_response :success

      assert_select ".checkout-line.is-blocked .checkout-line__name", text: "Sándwich de mantequilla de maní"
      assert_select ".checkout-line:not(.is-blocked) .checkout-line__name", text: "Arroz con pollo"
    end
  end

  test "create refuses the sale server-side when a blocked item is submitted, even directly" do
    student = build_student_with_allergy(restriction_type: "alergia_mani")
    blocked_item = @menu.fetch("Sándwich de mantequilla de maní")

    as_cafeteria_staff do
      assert_no_difference -> { Cafeteria::Purchase.count } do
        post "/cafeteria/checkouts", params: { student_id: student.id, item_ids: [ blocked_item.id ] }
      end
      assert_response :unprocessable_entity
      assert_select ".alert--danger", text: /bloqueada/
    end
  end

  test "create completes the sale for items with no matching allergen, recording a real purchase and charge" do
    student = build_student_with_allergy(restriction_type: "alergia_mani")
    item = @menu.fetch("Arroz con pollo")

    as_cafeteria_staff do
      assert_difference -> { Cafeteria::Purchase.count }, 1 do
        assert_difference -> { Finance::Charge.count }, 1 do
          post "/cafeteria/checkouts",
            params: { student_id: student.id, item_ids: [ item.id ], idempotency_key: SecureRandom.uuid }
        end
      end
      assert_redirected_to cafeteria_menu_path
      follow_redirect!
      assert_match "Compra registrada", flash[:notice].to_s
    end

    account = Finance::StudentAccount.find_by(institution_id: @institution.id, student_id: student.id)
    assert_equal BigDecimal("9500.00"), account.balance

    purchase = Cafeteria::Purchase.find_by!(institution_id: @institution.id, student_id: student.id)
    assert_equal "Arroz con pollo", purchase.item_names
    assert_equal BigDecimal("9500.00"), purchase.total_price_amount
  end

  test "idempotency: resubmitting the same idempotency_key never records a second purchase or charge" do
    student = build_student_with_allergy(restriction_type: "vegetariano") # never blocks
    item = @menu.fetch("Arroz con pollo")
    key = SecureRandom.uuid

    as_cafeteria_staff do
      post "/cafeteria/checkouts", params: { student_id: student.id, item_ids: [ item.id ], idempotency_key: key }
      post "/cafeteria/checkouts", params: { student_id: student.id, item_ids: [ item.id ], idempotency_key: key }
    end

    purchases = Cafeteria::Purchase.where(institution_id: @institution.id, student_id: student.id, idempotency_key: key)
    assert_equal 1, purchases.count, "re-submitting the same idempotency_key must never duplicate the sale"

    account = Finance::StudentAccount.find_by(institution_id: @institution.id, student_id: student.id)
    assert_equal BigDecimal("9500.00"), account.balance
  end

  test "a dietary PREFERENCE (never blocks) does not flag any menu line" do
    student = build_student_with_allergy(restriction_type: "vegetariano")

    as_cafeteria_staff do
      get "/cafeteria/checkouts/new", params: { student_id: student.student_code }
      assert_response :success
      assert_select ".checkout-line.is-blocked", count: 0
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

  test "balances index requires finance.read, not menu.view, and reads real accounts" do
    as_cafeteria_staff { get "/cafeteria/balances"; assert_response :forbidden }

    within_tenant(@institution) do
      grade = GroupManagement::GradeLevel.create!(institution: @institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: @institution, grade_level: grade, name: "9A", academic_year: 2026)
      s = GroupManagement::Student.create!(institution: @institution, grade_level: grade, section: section,
        first_name: "Bal", last_name: "Ance", gender: "female", birthdate: Date.new(2013, 3, 1),
        student_code: "CAF-BAL", entry_year: 2023, status: "active")
      Finance::StudentAccount.create!(institution: @institution, student: s, balance: "15000.0", currency: "COP")
    end

    as_treasury do
      get "/cafeteria/balances"
      assert_response :success
      assert_select "td", text: "9A"
      assert_match(/Bal Ance/, response.body)
    end
  end

  # --- portals: resolved by relation, no RBAC permission needed at all ------

  test "student portal cafeteria shows a zero balance with no grants and no student-self link" do
    with_grants do
      get "/portal/student/cafeteria"
      assert_response :success
      assert_select ".stat__value", text: "$0"
    end
  end

  test "guardian portal cafeteria shows the real balance of the guardian's own child after a real purchase" do
    student = build_student_with_allergy(restriction_type: "vegetariano")
    item = @menu.fetch("Yogurt con granola")

    as_cafeteria_staff do
      post "/cafeteria/checkouts",
        params: { student_id: student.id, item_ids: [ item.id ], idempotency_key: SecureRandom.uuid }
    end

    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente Caf",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: student,
        relationship: "madre", status: "active")
      user
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/cafeteria"
    assert_response :success
    assert_select ".stat__label", text: /Ana P/
    assert_select ".stat__value", text: "$3.800"
  end
end
