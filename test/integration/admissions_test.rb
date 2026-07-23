require "test_helper"

# guidelines/library_prompt.md, Fase D greenfield Increment 2 (Increment 1,
# `library`, closed v1.54.0). Base admissions pipeline: campaign -> applicant
# -> application -> (accepted) real GroupManagement::Student.
class AdmissionsTest < ActionDispatch::IntegrationTest
  def within_tenant(&block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      block.call
    end
  end

  setup { @user, @institution = sign_in_as_member }

  def as_campaign_manager(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "admissions_campaign_manager",
        permission_keys: %w[admissions.campaigns.manage], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_registrar(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "admissions_registrar", permission_keys: %w[admissions.intake],
        scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_reviewer(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "admissions_reviewer",
        permission_keys: %w[admissions.applications.manage], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_reviewer_scoped_to(grade_level, &block)
    with_grants(
      Authorization::Assignment.new(role_key: "admissions_reviewer_scoped",
        permission_keys: %w[admissions.applications.manage], scope_type: :grade_level, scope_id: grade_level.id),
      &block
    )
  end

  def build_grade_level(name: "Primero", level_number: 1)
    within_tenant { GroupManagement::GradeLevel.create!(institution: @institution, name: name, level_number: level_number) }
  end

  def build_campaign(fee_cents: 15_000)
    within_tenant do
      Admissions::Campaign.create!(institution: @institution, name: "Admisiones 2027", target_entry_year: 2027,
        opens_on: Date.current, closes_on: 1.month.from_now, status: "open", application_fee_cents: fee_cents)
    end
  end

  def build_applicant!(last_name: "Aspirante-#{SecureRandom.hex(3)}", guardian_email: "guardian-#{SecureRandom.hex(4)}@example.test")
    within_tenant do
      Admissions::Applicant.create!(institution: @institution, first_name: "Est", last_name: last_name,
        gender: "female", birthdate: Date.new(2019, 1, 1), guardian_name: "Acudiente Real",
        guardian_email: guardian_email)
    end
  end

  test "campaigns index requires admissions.campaigns.manage" do
    with_grants { get "/admissions/campaigns"; assert_response :forbidden }

    as_campaign_manager do
      get "/admissions/campaigns"
      assert_response :success
    end
  end

  test "campaign manager can open a new campaign" do
    as_campaign_manager do
      assert_difference -> { Admissions::Campaign.count }, 1 do
        post "/admissions/campaigns", params: { campaign: { name: "Admisiones 2028", target_entry_year: 2028,
          opens_on: Date.current, closes_on: 2.months.from_now, status: "open", application_fee_cents: 10_000 } }
      end
      assert_redirected_to admissions_campaigns_path
    end
  end

  test "registering an applicant is denied entirely without admissions.intake" do
    with_grants { get "/admissions/applicants/new"; assert_response :forbidden }
  end

  test "applications index requires admissions.applications.manage, not admissions.intake" do
    as_registrar { get "/admissions/applications"; assert_response :forbidden }

    as_reviewer do
      get "/admissions/applications"
      assert_response :success
    end
  end

  test "full pipeline: register applicant, submit application, attach a document, accept into a real Student" do
    grade_level = build_grade_level
    campaign = build_campaign(fee_cents: 15_000)

    applicant = as_registrar do
      assert_difference -> { Admissions::Applicant.count }, 1 do
        post "/admissions/applicants", params: { applicant: { first_name: "Sofía", last_name: "Gómez",
          gender: "female", birthdate: "2019-02-10", guardian_name: "Marta Gómez",
          guardian_email: "marta-#{SecureRandom.hex(4)}@example.test" } }
      end
      within_tenant { Admissions::Applicant.order(:created_at).last }
    end

    application = as_registrar do
      assert_difference -> { Admissions::Application.count }, 1 do
        post "/admissions/applications", params: { applicant_id: applicant.id, campaign_id: campaign.id,
          target_grade_level_id: grade_level.id, idempotency_key: SecureRandom.uuid }
      end
      within_tenant { Admissions::Application.order(:created_at).last }
    end

    as_registrar do
      file = fixture_file_upload(Rails.root.join("test/fixtures/files/attachment.pdf"), "application/pdf")
      assert_difference -> { Admissions::Document.count }, 1 do
        post "/admissions/applications/#{application.id}/documents",
          params: { document_type: "registro_civil", file: file }
      end
      assert_redirected_to admissions_application_path(application)
    end

    as_reviewer do
      code = "STU-#{SecureRandom.hex(3)}"
      post "/admissions/applications/#{application.id}/acceptance", params: { student_code: code }
      assert_redirected_to admissions_application_path(application)

      within_tenant do
        application.reload
        assert_equal "accepted", application.status
        student = application.converted_student
        assert_equal code, student.student_code
        assert_equal grade_level.id, student.grade_level_id

        assert Core::GuardianStudent.exists?(institution_id: @institution.id, student_id: student.id)
        assert Finance::StudentAccount.exists?(institution_id: @institution.id, student_id: student.id)
        charge = Finance::Charge.find_by(institution_id: @institution.id, student_id: student.id)
        assert charge
        assert_equal BigDecimal("150.00"), charge.amount
      end
    end
  end

  test "accepting is rejected entirely without admissions.applications.manage" do
    grade_level = build_grade_level
    campaign = build_campaign
    applicant = build_applicant!
    application = within_tenant do
      Admissions::ApplicationSubmitter.call(institution: @institution, applicant: applicant, campaign: campaign,
        target_grade_level: grade_level)
    end

    as_registrar do
      post "/admissions/applications/#{application.id}/acceptance", params: { student_code: "STU-X" }
      assert_response :forbidden
    end
  end

  test "a reviewer scoped to one grade level only sees applications targeting that grade" do
    grade_a = build_grade_level(name: "Primero", level_number: 1)
    grade_b = build_grade_level(name: "Segundo", level_number: 2)
    campaign = build_campaign
    applicant_a = build_applicant!
    applicant_b = build_applicant!

    application_a = within_tenant do
      Admissions::ApplicationSubmitter.call(institution: @institution, applicant: applicant_a, campaign: campaign,
        target_grade_level: grade_a)
    end
    within_tenant do
      Admissions::ApplicationSubmitter.call(institution: @institution, applicant: applicant_b, campaign: campaign,
        target_grade_level: grade_b)
    end

    as_reviewer_scoped_to(grade_a) do
      get "/admissions/applications"
      assert_response :success
      assert_match applicant_a.full_name, response.body
      assert_no_match applicant_b.full_name, response.body
    end
  end
end
