require "test_helper"

class Admissions::ApplicationStepTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "aas-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_grade_level(institution)
    GroupManagement::GradeLevel.create!(institution: institution, name: "Primero", level_number: 1)
  end

  def build_campaign(institution)
    Admissions::Campaign.create!(institution: institution, name: "Admisiones 2027", target_entry_year: 2027,
      opens_on: Date.current, closes_on: 1.month.from_now, status: "open")
  end

  def build_application(institution, campaign, grade_level)
    applicant = Admissions::Applicant.create!(institution: institution, first_name: "Est", last_name: "Aspirante",
      gender: "female", birthdate: Date.new(2019, 1, 1), guardian_name: "Acudiente",
      guardian_email: "guardian-#{SecureRandom.hex(4)}@example.test")
    Admissions::Application.create!(institution: institution, campaign: campaign, applicant: applicant,
      target_grade_level: grade_level, submitted_at: Time.current)
  end

  test "status is restricted to the closed vocabulary even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      application = build_application(institution, campaign, grade_level)
      template = Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Documentos",
        position: 1)
      step = Admissions::ApplicationStep.new(institution: institution, application: application,
        step_template: template, status: "bogus")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { step.save!(validate: false) }
      end
    end
  end

  test "a step can't have two rows for the same (application, step_template) — DB backstop bypassing app validation" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      application = build_application(institution, campaign, grade_level)
      template = Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Documentos",
        position: 1)
      Admissions::ApplicationStep.create!(institution: institution, application: application, step_template: template)
      duplicate = Admissions::ApplicationStep.new(institution: institution, application: application,
        step_template: template)

      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
    end
  end

  test "completed_at is stamped when status becomes completed, and cleared otherwise" do
    institution = build_institution
    within_tenant(institution) do
      grade_level = build_grade_level(institution)
      campaign = build_campaign(institution)
      application = build_application(institution, campaign, grade_level)
      template = Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Documentos",
        position: 1)
      step = Admissions::ApplicationStep.create!(institution: institution, application: application,
        step_template: template)

      assert_nil step.completed_at

      step.update!(status: "completed")
      assert_not_nil step.completed_at

      step.update!(status: "in_progress")
      assert_nil step.completed_at
    end
  end
end
