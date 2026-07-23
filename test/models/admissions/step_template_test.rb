require "test_helper"

class Admissions::StepTemplateTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "ast-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_campaign(institution)
    Admissions::Campaign.create!(institution: institution, name: "Admisiones 2027", target_entry_year: 2027,
      opens_on: Date.current, closes_on: 1.month.from_now, status: "open")
  end

  test "two steps in the same campaign cannot share a position — DB backstop even bypassing app validation" do
    institution = build_institution
    within_tenant(institution) do
      campaign = build_campaign(institution)
      Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Documentos", position: 1)
      duplicate = Admissions::StepTemplate.new(institution: institution, campaign: campaign, name: "Entrevista",
        position: 1)

      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
    end
  end

  test "campaign.step_templates is ordered by position" do
    institution = build_institution
    within_tenant(institution) do
      campaign = build_campaign(institution)
      Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Entrevista", position: 2)
      Admissions::StepTemplate.create!(institution: institution, campaign: campaign, name: "Documentos", position: 1)

      assert_equal [ "Documentos", "Entrevista" ], campaign.step_templates.map(&:name)
    end
  end
end
