require "test_helper"

# guidelines/library_prompt.md, Fase D greenfield increment 1. Molde
# Finance::ChargeCreator/Extracurriculars::EnrollmentCreator (lock,
# idempotent, transactional), adapted for the ONE shape neither has:
# guarding the LOCKED row's OWN status column.
class Library::LoanRecorderTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "lr-#{SecureRandom.hex(4)}"
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

  test "lends an available copy, flips its status, and creates the loan" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "LR-1")

      loan = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student, issued_by: staff)

      assert_equal "loaned", copy.reload.status
      assert_equal student.id, loan.borrower_student_id
      assert_equal "active", loan.status
    end
  end

  test "raises NotAvailable for a copy that is not available" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "LR-2")
      other_student = build_student(institution, "LR-3")

      Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student, issued_by: staff)

      assert_raises(Library::LoanRecorder::NotAvailable) do
        Library::LoanRecorder.call(institution: institution, copy: copy, borrower: other_student, issued_by: staff)
      end
    end
  end

  test "idempotent: calling twice with the same key returns the SAME loan, never double-lends" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "LR-4")
      key = SecureRandom.uuid

      first = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student,
        issued_by: staff, idempotency_key: key)
      second = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student,
        issued_by: staff, idempotency_key: key)

      assert_equal first.id, second.id
      assert_equal 1, Library::Loan.where(institution_id: institution.id, idempotency_key: key).count
    end
  end

  test "enforces MAX_ACTIVE_LOANS_STUDENT" do
    institution = build_institution
    within_tenant(institution) do
      staff = build_staff(institution)
      student = build_student(institution, "LR-5")

      Library::LoanRecorder::MAX_ACTIVE_LOANS_STUDENT.times do
        copy = build_copy(institution)
        Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student, issued_by: staff)
      end

      one_more = build_copy(institution)
      assert_raises(Library::LoanRecorder::BorrowLimitExceeded) do
        Library::LoanRecorder.call(institution: institution, copy: one_more, borrower: student, issued_by: staff)
      end
    end
  end

  test "staff borrowers get their own, higher limit (MAX_ACTIVE_LOANS_STAFF)" do
    institution = build_institution
    within_tenant(institution) do
      staff = build_staff(institution)
      borrower_staff = build_staff(institution)

      Library::LoanRecorder::MAX_ACTIVE_LOANS_STAFF.times do
        copy = build_copy(institution)
        Library::LoanRecorder.call(institution: institution, copy: copy, borrower: borrower_staff, issued_by: staff)
      end

      one_more = build_copy(institution)
      assert_raises(Library::LoanRecorder::BorrowLimitExceeded) do
        Library::LoanRecorder.call(institution: institution, copy: one_more, borrower: borrower_staff, issued_by: staff)
      end
    end
  end

  test "the partial unique index backstops double-lending even bypassing the service" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "LR-6")
      other_student = build_student(institution, "LR-7")

      Library::Loan.create!(institution: institution, copy: copy, issued_by: staff, borrower_student: student,
        borrowed_at: Time.current, due_at: 1.day.from_now, status: "active")
      second = Library::Loan.new(institution: institution, copy: copy, issued_by: staff,
        borrower_student: other_student, borrowed_at: Time.current, due_at: 1.day.from_now, status: "active")

      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { second.save!(validate: false) }
      end
    end
  end
end
