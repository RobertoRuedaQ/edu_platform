require "test_helper"

class Library::LoanTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "ll-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_student(institution, code)
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023, status: "active")
  end

  def build_staff(institution)
    user = Core::User.create!(email: "staff-#{SecureRandom.hex(4)}@member.test", name: "Bibliotecario",
      password: "password-123456")
    institution.memberships.create!(user: user)
  end

  def build_copy(institution)
    resource = Library::Resource.create!(institution: institution, title: "Cien años de soledad")
    Library::ResourceCopy.create!(institution: institution, resource: resource, barcode: "LIB-#{SecureRandom.hex(3)}")
  end

  test "exactly one borrower is required — neither both nor neither is valid" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "LL-1")

      neither = Library::Loan.new(institution: institution, copy: copy, issued_by: staff,
        borrowed_at: Time.current, due_at: 1.day.from_now, status: "active")
      assert_not neither.valid?

      both = Library::Loan.new(institution: institution, copy: copy, issued_by: staff,
        borrower_institution_user: staff, borrower_student: student,
        borrowed_at: Time.current, due_at: 1.day.from_now, status: "active")
      assert_not both.valid?

      exactly_one = Library::Loan.new(institution: institution, copy: copy, issued_by: staff,
        borrower_student: student, borrowed_at: Time.current, due_at: 1.day.from_now, status: "active")
      assert exactly_one.valid?
    end
  end

  test "borrower identity is ALSO enforced at the DB level, bypassing app validation" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)

      neither = Library::Loan.new(institution: institution, copy: copy, issued_by: staff,
        borrowed_at: Time.current, due_at: 1.day.from_now, status: "active")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { neither.save!(validate: false) }
      end
    end
  end

  test "status is restricted to the closed vocabulary even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "LL-2")

      loan = Library::Loan.new(institution: institution, copy: copy, issued_by: staff,
        borrower_student: student, borrowed_at: Time.current, due_at: 1.day.from_now, status: "bogus")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { loan.save!(validate: false) }
      end
    end
  end

  test "overdue? is computed, never persisted" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "LL-3")

      loan = Library::Loan.create!(institution: institution, copy: copy, issued_by: staff,
        borrower_student: student, borrowed_at: 20.days.ago, due_at: 6.days.ago, status: "active")

      assert loan.overdue?
      assert_equal "active", loan.status
    end
  end
end
