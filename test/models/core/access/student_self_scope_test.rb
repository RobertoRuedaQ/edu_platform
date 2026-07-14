require "test_helper"

class Core::Access::StudentSelfScopeTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "sss-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "returns the ONE student record owned by this user" do
    institution = build_institution

    within_tenant(institution) do
      user = Core::User.create!(email: "s@correo.test", name: "S")
      student = GroupManagement::Student.create!(institution: institution, national_id: "SS-1",
        first_name: "Est", last_name: "Prueba", gender: "male", birthdate: Date.new(2015, 1, 1),
        student_code: "SS-CODE", entry_year: 2026, user: user)

      result = Core::Access::StudentSelfScope.for(user, institution: institution)

      assert_equal student.id, result.id
    end
  end

  test "returns nil (never another user's record) when this user has no linked student" do
    institution = build_institution

    within_tenant(institution) do
      user = Core::User.create!(email: "nostudent@correo.test", name: "NoStudent")
      GroupManagement::Student.create!(institution: institution, national_id: "SS-2",
        first_name: "Otro", last_name: "Estudiante", gender: "female", birthdate: Date.new(2015, 1, 1),
        student_code: "SS-CODE-2", entry_year: 2026) # unlinked to any user

      assert_nil Core::Access::StudentSelfScope.for(user, institution: institution)
    end
  end

  test "never returns a student owned by this user in a DIFFERENT institution" do
    institution_i = build_institution
    institution_j = build_institution

    user = within_tenant(institution_i) { Core::User.create!(email: "cross-s@correo.test", name: "CrossS") }
    within_tenant(institution_j) do
      GroupManagement::Student.create!(institution: institution_j, national_id: "SS-J",
        first_name: "Est", last_name: "J", gender: "male", birthdate: Date.new(2015, 1, 1),
        student_code: "SS-J-CODE", entry_year: 2026, user: user)
    end

    within_tenant(institution_i) do
      assert_nil Core::Access::StudentSelfScope.for(user, institution: institution_i)
    end
  end
end
