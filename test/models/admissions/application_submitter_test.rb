require "test_helper"

class Admissions::ApplicationSubmitterTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "as-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_grade_level(institution)
    GroupManagement::GradeLevel.create!(institution: institution, name: "Primero", level_number: 1)
  end

  def build_campaign(institution, fee_cents: 15_000)
    Admissions::Campaign.create!(institution: institution, name: "Admisiones 2027", target_entry_year: 2027,
      opens_on: Date.current, closes_on: 1.month.from_now, status: "open", application_fee_cents: fee_cents)
  end

  def build_applicant(institution)
    Admissions::Applicant.create!(institution: institution, first_name: "Est", last_name: "Aspirante",
      gender: "female", birthdate: Date.new(2019, 1, 1), guardian_name: "Acudiente",
      guardian_email: "guardian-#{SecureRandom.hex(4)}@example.test")
  end

  test "submits an application, snapshotting the campaign's fee at submit time" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution, fee_cents: 20_000)
      applicant = build_applicant(institution)

      application = Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant,
        campaign: campaign, target_grade_level: grade_level)

      assert_equal "submitted", application.status
      assert_equal 20_000, application.fee_cents

      campaign.update!(application_fee_cents: 99_000)
      assert_equal 20_000, application.reload.fee_cents
    end
  end

  test "idempotent: calling twice with the same key returns the SAME application, never double-submits" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution)
      key = SecureRandom.uuid

      first = Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant,
        campaign: campaign, target_grade_level: grade_level, idempotency_key: key)
      second = Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant,
        campaign: campaign, target_grade_level: grade_level, idempotency_key: key)

      assert_equal first.id, second.id
      assert_equal 1, Admissions::Application.where(institution_id: institution.id, idempotency_key: key).count
    end
  end

  test "M1: a real submission emits one usage event, and resubmitting never duplicates it" do
    institution = build_institution
    ControlPlane::Addon.find_or_create_by!(key: "admissions") { |a| a.name = "Admisiones"; a.currency = "COP" }
      .update!(metered: true, unit: "solicitudes", included_quota: 100, overage_unit_price_cents: 500)

    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution)
      key = SecureRandom.uuid

      Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant, campaign: campaign,
        target_grade_level: grade_level, idempotency_key: key)

      events = ControlPlane::UsageEvent.where(institution_id: institution.id)
      assert_equal 1, events.count
      assert_equal "solicitudes", events.sole.unit

      Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant, campaign: campaign,
        target_grade_level: grade_level, idempotency_key: key)

      assert_equal 1, ControlPlane::UsageEvent.where(institution_id: institution.id).count
    end
  end

  test "generates a tracker token — only the digest is persisted, never the raw token" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution)

      application = Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant,
        campaign: campaign, target_grade_level: grade_level)

      assert application.tracker_token_digest.present?
      assert_equal 64, application.tracker_token_digest.length # SHA256 hex digest
    end
  end

  test "fans out one pending ApplicationStep per StepTemplate of the campaign, none if the campaign has none" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Revisión de documentos",
        position: 1)
      Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Entrevista", position: 2)
      applicant = build_applicant(institution)

      application = Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant,
        campaign: campaign, target_grade_level: grade_level)

      steps = application.application_steps.includes(:step_template).order("admission_step_templates.position")
      assert_equal 2, steps.count
      assert_equal %w[pending pending], steps.map(&:status)
      assert_equal [ "Revisión de documentos", "Entrevista" ], steps.map { |s| s.step_template.name }
    end
  end

  test "a campaign with no step templates fans out zero steps" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution)

      application = Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant,
        campaign: campaign, target_grade_level: grade_level)

      assert_equal 0, application.application_steps.count
    end
  end

  test "enqueues the tracker email only on real creation, never on a resubmit" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      applicant = build_applicant(institution)
      key = SecureRandom.uuid

      assert_enqueued_emails 1 do
        Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant, campaign: campaign,
          target_grade_level: grade_level, idempotency_key: key)
      end

      assert_enqueued_emails 0 do
        Admissions::ApplicationSubmitter.call(institution: institution, applicant: applicant, campaign: campaign,
          target_grade_level: grade_level, idempotency_key: key)
      end
    end
  end
end
