require "test_helper"

class Admissions::AcceptanceConverterTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "acc-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_grade_level(institution)
    GroupManagement::GradeLevel.create!(institution: institution, name: "Primero", level_number: 1)
  end

  def build_campaign(institution, fee_cents: 15_000)
    Admissions::Campaign.create!(institution: institution, name: "Admisiones 2027", target_entry_year: 2027,
      opens_on: Date.current, closes_on: 1.month.from_now, status: "open", application_fee_cents: fee_cents)
  end

  def build_staff(institution)
    user = Core::User.create!(email: "staff-#{SecureRandom.hex(4)}@member.test", name: "Registrador",
      password: "password-123456")
    institution.memberships.create!(user: user)
  end

  def build_application(institution, campaign:, grade_level:, guardian_email: "guardian-#{SecureRandom.hex(4)}@example.test")
    applicant = Admissions::Applicant.create!(institution: institution, first_name: "Est", last_name: "Aspirante",
      gender: "female", birthdate: Date.new(2019, 1, 1), guardian_name: "Acudiente Real",
      guardian_email: guardian_email)
    Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant, campaign: campaign,
      target_grade_level: grade_level)
  end

  test "accepting creates a real Student, links the guardian, and charges the fee" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution, fee_cents: 15_000)
      staff = build_staff(institution)
      application = build_application(institution, campaign: campaign, grade_level: grade_level)
      code = "STU-#{SecureRandom.hex(3)}"

      student = Admissions::AcceptanceConverter.call(institution: institution, application: application,
        student_code: code, decided_by: staff)

      assert_equal code, student.student_code
      assert_equal grade_level.id, student.grade_level_id
      assert_equal "accepted", application.reload.status
      assert_equal student.id, application.converted_student_id

      link = Core::GuardianStudent.find_by(institution_id: institution.id, student_id: student.id)
      assert link
      assert_equal application.applicant.guardian_email, link.guardian.email

      account = Finance::StudentAccount.find_by(institution_id: institution.id, student_id: student.id)
      assert account
      charge = Finance::Charge.find_by(institution_id: institution.id, student_id: student.id)
      assert charge
      assert_equal BigDecimal("150.00"), charge.amount
    end
  end

  test "a free campaign (fee_cents == 0) never generates a Finance::Charge" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution, fee_cents: 0)
      staff = build_staff(institution)
      application = build_application(institution, campaign: campaign, grade_level: grade_level)

      student = Admissions::AcceptanceConverter.call(institution: institution, application: application,
        student_code: "STU-#{SecureRandom.hex(3)}", decided_by: staff)

      assert_nil Finance::Charge.find_by(institution_id: institution.id, student_id: student.id)
    end
  end

  test "idempotent: calling twice returns the SAME student, never a second Student/Charge" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      staff = build_staff(institution)
      application = build_application(institution, campaign: campaign, grade_level: grade_level)

      first = Admissions::AcceptanceConverter.call(institution: institution, application: application,
        student_code: "STU-#{SecureRandom.hex(3)}", decided_by: staff)
      second = Admissions::AcceptanceConverter.call(institution: institution, application: application,
        student_code: "IGNORED", decided_by: staff)

      assert_equal first.id, second.id
      assert_equal 1, GroupManagement::Student.where(institution_id: institution.id).count
      assert_equal 1, Finance::Charge.where(institution_id: institution.id, student_id: first.id).count
    end
  end

  test "raises NotReviewable if the application was already rejected" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      staff = build_staff(institution)
      application = build_application(institution, campaign: campaign, grade_level: grade_level)
      application.update!(status: "rejected")

      assert_raises(Admissions::AcceptanceConverter::NotReviewable) do
        Admissions::AcceptanceConverter.call(institution: institution, application: application,
          student_code: "STU-#{SecureRandom.hex(3)}", decided_by: staff)
      end
    end
  end
end
