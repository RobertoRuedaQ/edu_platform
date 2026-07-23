require "test_helper"

# guidelines/library_prompt.md, Fase D greenfield Increment 3. Public
# applicant tracker: no session, no RBAC — RLS + institution_id explícito
# son el único portón. Criterio de aceptación explícito de la spec:
# private_notes/identidad del evaluador NUNCA se renderizan aquí.
class AdmissionsTrackerTest < ActionDispatch::IntegrationTest
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

  def as_reviewer(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "admissions_reviewer",
        permission_keys: %w[admissions.applications.manage], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def build_grade_level
    within_tenant { GroupManagement::GradeLevel.create!(institution: @institution, name: "Primero", level_number: 1) }
  end

  def build_campaign
    within_tenant do
      Admissions::Campaign.create!(institution: @institution, name: "Admisiones 2027", target_entry_year: 2027,
        opens_on: Date.current, closes_on: 1.month.from_now, status: "open")
    end
  end

  def build_step_template(campaign, name:, position:)
    within_tenant { Admissions::StepTemplate.create!(institution: @institution, campaign: campaign, name: name, position: position) }
  end

  def build_applicant!(guardian_email:)
    within_tenant do
      Admissions::Applicant.create!(institution: @institution, first_name: "Sofía", last_name: "Gómez",
        gender: "female", birthdate: Date.new(2019, 2, 10), guardian_name: "Marta Gómez",
        guardian_email: guardian_email)
    end
  end

  # Extracts the raw token off the delivered tracker email — molde
  # test_helper.rb's `last_otp_code` (only the digest is ever persisted, so
  # this is the only way to get a usable token in a test, same as a real
  # applicant would from their inbox).
  def last_tracker_token
    mail = ActionMailer::Base.deliveries.last
    body = (mail.text_part || mail.html_part || mail).body.to_s
    body[%r{admisiones/solicitud/([\w-]+)}, 1]
  end

  test "full pipeline: submit with steps, then the public tracker shows status/steps but NEVER private_notes/evaluator" do
    grade_level = build_grade_level
    campaign = build_campaign
    build_step_template(campaign, name: "Revisión de documentos", position: 1)
    build_step_template(campaign, name: "Entrevista", position: 2)
    applicant = build_applicant!(guardian_email: "marta-#{SecureRandom.hex(4)}@example.test")

    application = within_tenant do
      perform_enqueued_jobs do
        Admissions::ApplicationSubmitter.call(institution: @institution, applicant: applicant, campaign: campaign,
          target_grade_level: grade_level)
      end
    end

    staff_user = within_tenant do
      Core::User.create!(email: "eval-#{SecureRandom.hex(4)}@member.test", name: "Evaluador Confidencial",
        password: "password-123456")
    end
    evaluator = within_tenant { @institution.memberships.create!(user: staff_user) }
    step = within_tenant { application.application_steps.order(:created_at).first }
    within_tenant { step.update!(status: "completed", private_notes: "NOTA SECRETA DEL EVALUADOR", evaluator: evaluator) }

    token = last_tracker_token
    assert token.present?

    host! "#{@institution.slug}.example.com"
    get "/admisiones/solicitud/#{token}"
    assert_response :success

    assert_match "Sofía Gómez", response.body
    assert_match "Revisión de documentos", response.body
    assert_match "Entrevista", response.body
    assert_no_match "NOTA SECRETA", response.body
    assert_no_match "Evaluador Confidencial", response.body
    assert_no_match staff_user.email, response.body
  end

  test "an invalid token 404s" do
    host! "#{@institution.slug}.example.com"
    get "/admisiones/solicitud/not-a-real-token"
    assert_response :not_found
  end

  test "a valid token requested from a DIFFERENT institution's subdomain 404s — real tenant isolation, not just token matching" do
    grade_level = build_grade_level
    campaign = build_campaign
    applicant = build_applicant!(guardian_email: "marta-#{SecureRandom.hex(4)}@example.test")
    within_tenant do
      perform_enqueued_jobs do
        Admissions::ApplicationSubmitter.call(institution: @institution, applicant: applicant, campaign: campaign,
          target_grade_level: grade_level)
      end
    end
    token = last_tracker_token

    other_slug = "otro-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Otro Colegio", slug: other_slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")

    host! "#{other_slug}.example.com"
    get "/admisiones/solicitud/#{token}"
    assert_response :not_found
  end

  test "without a resolvable subdomain the tracker 404s" do
    build_grade_level
    host! "www.example.com" # reserved subdomain, resolves to no institution
    get "/admisiones/solicitud/some-token"
    assert_response :not_found
  end

  test "step templates CRUD requires admissions.campaigns.manage" do
    campaign = build_campaign
    with_grants { get "/admissions/campaigns/#{campaign.id}/step_templates"; assert_response :forbidden }

    as_campaign_manager do
      assert_difference -> { Admissions::StepTemplate.count }, 1 do
        post "/admissions/campaigns/#{campaign.id}/step_templates",
          params: { step_template: { name: "Entrevista", position: 1 } }
      end
    end
  end

  test "updating an application step requires admissions.applications.manage" do
    grade_level = build_grade_level
    campaign = build_campaign
    build_step_template(campaign, name: "Entrevista", position: 1)
    applicant = build_applicant!(guardian_email: "marta-#{SecureRandom.hex(4)}@example.test")
    application = within_tenant do
      Admissions::ApplicationSubmitter.call(institution: @institution, applicant: applicant, campaign: campaign,
        target_grade_level: grade_level)
    end
    step = within_tenant { application.application_steps.first }

    with_grants do
      patch "/admissions/applications/#{application.id}/steps/#{step.id}", params: { application_step: { status: "completed" } }
      assert_response :forbidden
    end

    as_reviewer do
      patch "/admissions/applications/#{application.id}/steps/#{step.id}", params: { application_step: { status: "completed" } }
      assert_redirected_to admissions_application_path(application)
    end

    within_tenant { assert_equal "completed", step.reload.status }
  end
end
