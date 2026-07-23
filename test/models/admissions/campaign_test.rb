require "test_helper"

class Admissions::CampaignTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "ac-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "status is restricted to the closed vocabulary even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      campaign = Admissions::Campaign.new(institution: institution, name: "Admisiones 2027", target_entry_year: 2027,
        opens_on: Date.current, closes_on: 1.month.from_now, status: "bogus")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { campaign.save!(validate: false) }
      end
    end
  end

  test "application_fee_amount bridges cents to a BigDecimal, never a Float" do
    institution = build_institution
    within_tenant(institution) do
      campaign = Admissions::Campaign.create!(institution: institution, name: "Admisiones 2027",
        target_entry_year: 2027, opens_on: Date.current, closes_on: 1.month.from_now, application_fee_cents: 15_000)

      assert_equal BigDecimal("150.00"), campaign.application_fee_amount
    end
  end
end
