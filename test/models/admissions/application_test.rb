require "test_helper"

class Admissions::ApplicationTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "aap-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_grade_level(institution, name: "Primero", level_number: 1)
    GroupManagement::GradeLevel.create!(institution: institution, name: name, level_number: level_number)
  end

  def build_campaign(institution)
    Admissions::Campaign.create!(institution: institution, name: "Admisiones 2027", target_entry_year: 2027,
      opens_on: Date.current, closes_on: 1.month.from_now, status: "open")
  end

  def build_applicant(institution, suffix)
    Admissions::Applicant.create!(institution: institution, first_name: "Est", last_name: suffix,
      gender: "female", birthdate: Date.new(2019, 1, 1), guardian_name: "Acudiente #{suffix}",
      guardian_email: "guardian-#{suffix}-#{SecureRandom.hex(3)}@example.test")
  end

  test "status is restricted to the closed vocabulary even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution, "AT-1")

      application = Admissions::Application.new(institution: institution, campaign: campaign, applicant: applicant,
        target_grade_level: grade_level, status: "bogus", submitted_at: Time.current)

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { application.save!(validate: false) }
      end
    end
  end

  test "an applicant cannot apply twice to the same campaign — DB backstop even bypassing app validation" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution, "AT-2")

      Admissions::Application.create!(institution: institution, campaign: campaign, applicant: applicant,
        target_grade_level: grade_level, submitted_at: Time.current)
      duplicate = Admissions::Application.new(institution: institution, campaign: campaign, applicant: applicant,
        target_grade_level: grade_level, submitted_at: Time.current)

      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
    end
  end

  test "converted_student_id is unique — no two applications can point at the same Student" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant_a = build_applicant(institution, "AT-3")
      applicant_b = build_applicant(institution, "AT-4")
      student = GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: "Convertido",
        gender: "female", birthdate: Date.new(2019, 1, 1), student_code: "AT-STU-#{SecureRandom.hex(3)}",
        entry_year: 2027, grade_level: grade_level)

      Admissions::Application.create!(institution: institution, campaign: campaign, applicant: applicant_a,
        target_grade_level: grade_level, submitted_at: Time.current, status: "accepted",
        converted_student: student)
      duplicate = Admissions::Application.new(institution: institution, campaign: campaign, applicant: applicant_b,
        target_grade_level: grade_level, submitted_at: Time.current, status: "accepted",
        converted_student: student)

      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
    end
  end

  test "grade_level_id aliases target_grade_level_id, molde Transportation::Route#route_id" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution, "AT-5")

      application = Admissions::Application.create!(institution: institution, campaign: campaign,
        applicant: applicant, target_grade_level: grade_level, submitted_at: Time.current)

      assert_equal grade_level.id, application.grade_level_id
    end
  end

  test "fee_amount bridges cents to a BigDecimal, and is nil when free" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution, "AT-6")

      paid = Admissions::Application.create!(institution: institution, campaign: campaign, applicant: applicant,
        target_grade_level: grade_level, submitted_at: Time.current, fee_cents: 15_000)
      assert_equal BigDecimal("150.00"), paid.fee_amount

      free_applicant = build_applicant(institution, "AT-7")
      free = Admissions::Application.create!(institution: institution, campaign: campaign,
        applicant: free_applicant, target_grade_level: grade_level, submitted_at: Time.current, fee_cents: 0)
      assert_nil free.fee_amount
    end
  end
end
