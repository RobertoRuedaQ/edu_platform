require "test_helper"

class Admissions::ApplicantTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "aa-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "gender is restricted to the closed vocabulary even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      applicant = Admissions::Applicant.new(institution: institution, first_name: "Ana", last_name: "Pérez",
        gender: "bogus", birthdate: Date.new(2019, 1, 1), guardian_name: "Luis Pérez",
        guardian_email: "luis@example.test")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { applicant.save!(validate: false) }
      end
    end
  end

  test "an applicant never touches Core::User/Core::InstitutionUser" do
    institution = build_institution
    within_tenant(institution) do
      applicant = Admissions::Applicant.create!(institution: institution, first_name: "Ana", last_name: "Pérez",
        gender: "female", birthdate: Date.new(2019, 1, 1), guardian_name: "Luis Pérez",
        guardian_email: "luis-#{SecureRandom.hex(4)}@example.test")

      assert_not applicant.respond_to?(:user)
      assert_not applicant.respond_to?(:institution_user)
    end
  end
end
