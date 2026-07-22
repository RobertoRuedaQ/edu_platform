require "test_helper"

# guidelines/CLOSURE_PLAN.md Fase D — cafeteria resto: Cafeteria::Purchase +
# Cafeteria::PurchaseRecorder retire the "STILL STUB" checkout half
# (CheckoutsController used to just flash a notice and persist nothing).
class Cafeteria::PurchaseTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "pu-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_student(institution, code)
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023, status: "active")
  end

  def build_staff_member(institution)
    user = Core::User.create!(email: "staff-#{SecureRandom.hex(4)}@member.test", name: "Cajero",
      password: "password-123456")
    institution.memberships.create!(user: user)
  end

  test "PurchaseRecorder creates exactly one Charge and Purchase, and increases the account balance" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "PU-1")
      recorded_by = build_staff_member(institution)
      item = Cafeteria::MenuItem.create!(institution: institution, name: "Arroz con pollo",
        category: "Almuerzo", price_cents: 950_000)

      purchase = Cafeteria::PurchaseRecorder.call(institution: institution, student: student,
        menu_items: [ item ], recorded_by: recorded_by, idempotency_key: SecureRandom.uuid)

      assert_equal 1, purchase.purchase_lines.count
      assert_equal BigDecimal("9500"), purchase.total_price_amount
      assert_equal BigDecimal("9500"), purchase.charge.amount

      account = Finance::StudentAccount.find_by!(institution_id: institution.id, student_id: student.id)
      assert_equal BigDecimal("9500"), account.balance
    end
  end

  test "PurchaseRecorder is idempotent: calling twice with the same key returns the SAME purchase" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "PU-2")
      recorded_by = build_staff_member(institution)
      item = Cafeteria::MenuItem.create!(institution: institution, name: "Arroz con pollo",
        category: "Almuerzo", price_cents: 950_000)
      key = SecureRandom.uuid

      first = Cafeteria::PurchaseRecorder.call(institution: institution, student: student,
        menu_items: [ item ], recorded_by: recorded_by, idempotency_key: key)
      second = Cafeteria::PurchaseRecorder.call(institution: institution, student: student,
        menu_items: [ item ], recorded_by: recorded_by, idempotency_key: key)

      assert_equal first.id, second.id
      assert_equal 1, Cafeteria::Purchase.where(institution_id: institution.id, idempotency_key: key).count
      assert_equal 1, Finance::Charge.where(institution_id: institution.id, idempotency_key: key).count

      account = Finance::StudentAccount.find_by!(institution_id: institution.id, student_id: student.id)
      assert_equal BigDecimal("9500"), account.balance, "resubmitting must never double-charge"
    end
  end

  test "total_price_cents must be positive even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      student = build_student(institution, "PU-3")
      recorded_by = build_staff_member(institution)
      charge = Finance::Charge.create!(institution: institution, student: student, invoice_number: "INV-PU-3",
        amount: BigDecimal("1"), currency: "COP", status: "pending")

      purchase = Cafeteria::Purchase.new(institution: institution, student: student, recorded_by: recorded_by,
        charge: charge, purchased_at: Time.current, total_price_cents: 0)

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { purchase.save!(validate: false) }
      end
    end
  end
end
