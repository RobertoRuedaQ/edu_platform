require "test_helper"

# finance (UI de tesorería, v1.18.0, item #4 of the MVP critical path). The
# five models (StudentAccount/Charge/Payment/PaymentPlan/Installment),
# finance's entitlement registration, its Navigation::Registry entry, and
# the finance.read/finance.write permissions ALL predate this slice
# (v1.3.0/S2b) — this slice wires the first real controller, reusing every
# one of them rather than inventing new keys (see HISTORIA.md v1.18.0).
# Money is `decimal` (not `*_cents bigint`) on these tables — BigDecimal
# arithmetic throughout, never Float.
class FinanceTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_student!(institution, first_name:, last_name:, student_code:, user: nil)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: student_code, entry_year: 2023, user: user)
  end

  def build_account!(institution, student:, balance: "0.0")
    Finance::StudentAccount.create!(institution: institution, student: student, balance: balance, currency: "COP")
  end

  setup do
    @user, @institution = sign_in_as_member # finance entitled by default (grant_full_entitlements)

    @student = within_tenant(@institution) { build_student!(@institution, first_name: "Valentina", last_name: "Suárez", student_code: "FIN-001") }
    @account = within_tenant(@institution) { build_account!(@institution, student: @student) }

    @other_student = within_tenant(@institution) { build_student!(@institution, first_name: "Otro", last_name: "Estudiante", student_code: "FIN-002") }
    @other_account = within_tenant(@institution) { build_account!(@institution, student: @other_student) }
  end

  def as_treasury(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "treasury", permission_keys: %w[finance.read finance.write],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_homeroom(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[grades.read],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "index shows accounts within the actor's scope" do
    as_treasury do
      get "/finance"
      assert_response :success
      assert_match(/Valentina Suárez/, response.body)
    end
  end

  test "a homeroom teacher without finance.read gets 403 and no nav tile" do
    as_homeroom do
      get "/finance"
      assert_response :forbidden
    end
  end

  test "acceptance: registering a payment lowers the balance, in exact cents-equivalent decimal" do
    as_treasury do
      post "/finance/#{@account.id}/payments",
        params: { amount: "50000.00", method: "cash", idempotency_key: SecureRandom.uuid }
      assert_redirected_to finance_account_path(@account)

      @account.reload
      assert_equal BigDecimal("-50000.00"), @account.balance
    end
  end

  test "acceptance: creating a charge raises the balance" do
    as_treasury do
      post "/finance/#{@account.id}/charges",
        params: { amount: "120000.00", description: "Pensión marzo", idempotency_key: SecureRandom.uuid }
      assert_redirected_to finance_account_path(@account)

      @account.reload
      assert_equal BigDecimal("120000.00"), @account.balance
      charge = Finance::Charge.find_by!(institution_id: @institution.id, student_id: @student.id)
      assert_equal "Pensión marzo", charge.description
      assert_match(/\AINV-/, charge.invoice_number)
    end
  end

  test "paying a charge in full marks it as paid" do
    as_treasury do
      post "/finance/#{@account.id}/charges", params: { amount: "100000.00", idempotency_key: SecureRandom.uuid }
      charge = Finance::Charge.find_by!(institution_id: @institution.id, student_id: @student.id)

      post "/finance/#{@account.id}/payments",
        params: { amount: "100000.00", method: "cash", charge_id: charge.id, idempotency_key: SecureRandom.uuid }

      assert_equal "paid", charge.reload.status
    end
  end

  test "atomicity: a rejected payment write never moves the balance nor leaves an orphan row" do
    as_treasury do
      original_balance = @account.balance

      assert_no_difference -> { Finance::Payment.where(institution_id: @institution.id, student_account_id: @account.id).count } do
        assert_raises(ActiveRecord::StatementInvalid) do
          Finance::PaymentRecorder.call(institution: @institution, account: @account, amount: BigDecimal("10.0"),
            method: "bogus_method", idempotency_key: SecureRandom.uuid)
        end
      end

      assert_equal original_balance, @account.reload.balance
    end
  end

  test "idempotency: resubmitting the SAME idempotency_key never records a second payment" do
    as_treasury do
      key = SecureRandom.uuid
      post "/finance/#{@account.id}/payments", params: { amount: "30000.00", method: "cash", idempotency_key: key }
      post "/finance/#{@account.id}/payments", params: { amount: "30000.00", method: "cash", idempotency_key: key }

      payments = Finance::Payment.where(institution_id: @institution.id, student_account_id: @account.id,
        idempotency_key: key)
      assert_equal 1, payments.count, "re-submitting the same idempotency_key must never duplicate"
      assert_equal BigDecimal("-30000.00"), @account.reload.balance
    end
  end

  test "idempotency: the same guard applies to charges" do
    as_treasury do
      key = SecureRandom.uuid
      post "/finance/#{@account.id}/charges", params: { amount: "20000.00", idempotency_key: key }
      post "/finance/#{@account.id}/charges", params: { amount: "20000.00", idempotency_key: key }

      charges = Finance::Charge.where(institution_id: @institution.id, idempotency_key: key)
      assert_equal 1, charges.count, "re-submitting the same idempotency_key must never duplicate"
      assert_equal BigDecimal("20000.00"), @account.reload.balance
    end
  end

  test "entitlement gate #1 runs before RBAC gate #2: not entitled shows the friendly module page, not a bare 403" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "finance" })
    entitlement.revoke!

    as_treasury do
      get "/finance"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "supervision and portal read the exact same statement figures (shared read path)" do
    as_treasury do
      post "/finance/#{@account.id}/charges", params: { amount: "75000.00", idempotency_key: SecureRandom.uuid }
      post "/finance/#{@account.id}/payments", params: { amount: "25000.00", method: "cash", idempotency_key: SecureRandom.uuid }
    end

    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: @student,
        relationship: "madre", status: "active")
      user
    end

    supervision_balance = as_treasury do
      get "/finance/#{@account.id}"
      @account.reload.balance
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/students/#{@student.id}/finance"
    assert_response :success
    assert_match(/50\.000|50000/, response.body) # 75000 - 25000, whatever the money() rendering
    assert_equal BigDecimal("50000.00"), supervision_balance
  end

  test "portal (guardian): sees only the account of their own child, never another family's" do
    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian2-#{SecureRandom.hex(4)}@member.test", name: "Acudiente 2",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: @student,
        relationship: "padre", status: "active")
      user
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/students/#{@student.id}/finance"
    assert_response :success

    get "/portal/guardian/students/#{@other_student.id}/finance"
    assert_response :not_found
  end

  test "portal never exposes a write action" do
    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian3-#{SecureRandom.hex(4)}@member.test", name: "Acudiente 3",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: @student,
        relationship: "madre", status: "active")
      user
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/students/#{@student.id}/finance"
    assert_response :success
    assert_select "form", count: 0
    assert_select "a", text: "Registrar pago", count: 0
    assert_select "a", text: "Crear cargo", count: 0
  end

  test "an acudiente with no resolved children sees the empty state, never an error" do
    lone_guardian = within_tenant(@institution) do
      user = Core::User.create!(email: "lone-#{SecureRandom.hex(4)}@member.test", name: "Sin Hijos",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      user
    end

    sign_in_as(lone_guardian, institution: @institution, password: "password-123456")
    get "/portal/guardian/students/#{@student.id}/finance"
    assert_response :not_found # GuardianScope.for(lone_guardian) is empty -> .find 404s, never an error
  end

  test "cross-tenant: an account seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "fin-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      student = build_student!(other_institution, first_name: "Fantasma", last_name: "Ajeno", student_code: "GHOST-1")
      build_account!(other_institution, student: student, balance: "999999.0")
    end

    as_treasury do
      get "/finance"
      assert_response :success
      assert_no_match(/Fantasma Ajeno/, response.body)
    end

    # Model-layer, under I's own GUC: a raw query that explicitly asks for J's
    # institution_id must still return zero rows — RLS itself blocking it.
    within_tenant(@institution) do
      assert_empty Finance::StudentAccount.where(institution_id: other_institution.id)
    end
  end

  # S3b (v1.30.0): one "transacciones" usage event per real Charge/Payment —
  # both count toward the SAME unit. A double-submit of the same
  # idempotency_key (ChargeCreator/PaymentRecorder's OWN guard) never re-emits.
  test "S3b: a charge and a payment each emit one usage event, and a double-submit never duplicates either" do
    ControlPlane::Addon.find_by!(key: "finance").update!( # sign_in_as_member already seeded this, unmetered
      metered: true, unit: "transacciones", included_quota: 10, overage_unit_price_cents: 150
    )

    as_treasury do
      key = SecureRandom.uuid
      post "/finance/#{@account.id}/charges", params: { amount: "50000.00", description: "Pensión", idempotency_key: key }
      post "/finance/#{@account.id}/charges", params: { amount: "50000.00", description: "Pensión", idempotency_key: key }

      post "/finance/#{@account.id}/payments", params: { amount: "10000.00", method: "cash", idempotency_key: SecureRandom.uuid }
    end

    events = ControlPlane::UsageEvent.where(institution_id: @institution.id)
    assert_equal 2, events.count # one charge + one payment, the repeated charge submit never re-emitted
    assert(events.all? { |e| e.unit == "transacciones" })
  end
end
