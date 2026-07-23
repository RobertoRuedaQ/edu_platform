require "test_helper"

class Admissions::Tracker::PublicViewTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "atpv-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  # Allowlist por construcción (molde AnalyticsBi::Lens::AuraScope, guardrail
  # v1.37.0) — verificado a nivel de MODELO: los Data ni siquiera EXPONEN un
  # accessor para los campos sensibles, así que ninguna vista futura puede
  # filtrarlos por descuido.
  test "Result/StepView never expose private_notes or evaluator identity, by construction" do
    refute_includes Admissions::Tracker::PublicView::Result.members, :private_notes
    refute_includes Admissions::Tracker::PublicView::Result.members, :evaluator_institution_user_id
    refute_includes Admissions::Tracker::PublicView::StepView.members, :private_notes
    refute_includes Admissions::Tracker::PublicView::StepView.members, :evaluator_institution_user_id
    refute_includes Admissions::Tracker::PublicView::StepView.members, :evaluator
  end

  test "builds a Result from a real application, with steps ordered by position" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = GroupManagement::GradeLevel.create!(institution: institution, name: "Primero", level_number: 1)
      campaign = Admissions::Campaign.create!(institution: institution, name: "Admisiones 2027",
        target_entry_year: 2027, opens_on: Date.current, closes_on: 1.month.from_now, status: "open")
      applicant = Admissions::Applicant.create!(institution: institution, first_name: "Sofía", last_name: "Gómez",
        gender: "female", birthdate: Date.new(2019, 1, 1), guardian_name: "Marta",
        guardian_email: "marta-#{SecureRandom.hex(4)}@example.test")
      application = Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant,
        campaign: campaign, target_grade_level: grade_level)
      staff_user = Core::User.create!(email: "eval-#{SecureRandom.hex(4)}@member.test", name: "Evaluador Secreto",
        password: "password-123456")
      evaluator = institution.memberships.create!(user: staff_user)
      template = Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Entrevista",
        position: 1)
      step = Admissions::ApplicationStep.create!(institution: institution, application: application,
        step_template: template)
      step.update!(status: "completed", private_notes: "NOTA SECRETA", evaluator: evaluator)

      tracker = Admissions::Tracker::PublicView.for(application.reload)

      assert_equal "Sofía Gómez", tracker.applicant_name
      assert_equal "Admisiones 2027", tracker.campaign_name
      assert_equal "Primero", tracker.grade_level_name
      assert_equal "submitted", tracker.status
      assert_equal 1, tracker.steps.size
      assert_equal "Entrevista", tracker.steps.first.name
      assert_equal "completed", tracker.steps.first.status
    end
  end
end
