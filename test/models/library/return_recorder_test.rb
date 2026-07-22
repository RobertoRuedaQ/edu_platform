require "test_helper"

class Library::ReturnRecorderTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "rr-#{SecureRandom.hex(4)}"
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

  test "returns an active loan and flips the copy back to available" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "RR-1")
      loan = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student, issued_by: staff)

      Library::ReturnRecorder.call(institution: institution, loan: loan)

      assert_equal "available", copy.reload.status
      assert_equal "returned", loan.reload.status
      assert_not_nil loan.returned_at
    end
  end

  test "idempotent: returning an already-returned loan is a no-op, never raises" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "RR-2")
      loan = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student, issued_by: staff)

      Library::ReturnRecorder.call(institution: institution, loan: loan)
      returned_at_first = loan.reload.returned_at
      Library::ReturnRecorder.call(institution: institution, loan: loan)

      assert_equal returned_at_first, loan.reload.returned_at
    end
  end

  test "raises InvalidState for a loan that is not active (e.g. lost)" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "RR-3")
      loan = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student, issued_by: staff)
      loan.update!(status: "lost")

      assert_raises(Library::ReturnRecorder::InvalidState) do
        Library::ReturnRecorder.call(institution: institution, loan: loan)
      end
    end
  end

  test "after returning, the same copy can be lent again" do
    institution = build_institution
    within_tenant(institution) do
      copy = build_copy(institution)
      staff = build_staff(institution)
      student = build_student(institution, "RR-4")
      other_student = build_student(institution, "RR-5")

      first_loan = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: student, issued_by: staff)
      Library::ReturnRecorder.call(institution: institution, loan: first_loan)

      second_loan = Library::LoanRecorder.call(institution: institution, copy: copy, borrower: other_student, issued_by: staff)

      assert_equal "loaned", copy.reload.status
      assert_equal other_student.id, second_loan.borrower_student_id
    end
  end
end
