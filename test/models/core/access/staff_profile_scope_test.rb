require "test_helper"

class Core::Access::StaffProfileScopeTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "sps-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "returns the ONE staff_member record owned by this user" do
    institution = build_institution

    within_tenant(institution) do
      user = Core::User.create!(email: "staff@correo.test", name: "Staff")
      iu = institution.memberships.create!(user: user)
      staff_member = StaffManagement::StaffMember.create!(institution: institution, institution_user: iu,
        employee_number: "EMP-1", staff_category: "teaching", employment_type: "full_time")

      result = Core::Access::StaffProfileScope.for(user, institution: institution)

      assert_equal staff_member.id, result.id
    end
  end

  test "returns nil (a normal empty state, not an error) when this person has no staff_member row" do
    institution = build_institution

    within_tenant(institution) do
      user = Core::User.create!(email: "noprofile@correo.test", name: "Sin Perfil")
      institution.memberships.create!(user: user)

      assert_nil Core::Access::StaffProfileScope.for(user, institution: institution)
    end
  end

  test "never returns another person's staff_member row" do
    institution = build_institution

    within_tenant(institution) do
      user_a = Core::User.create!(email: "a2@correo.test", name: "A2")
      user_b = Core::User.create!(email: "b2@correo.test", name: "B2")
      institution.memberships.create!(user: user_a)
      iu_b = institution.memberships.create!(user: user_b)
      StaffManagement::StaffMember.create!(institution: institution, institution_user: iu_b,
        employee_number: "EMP-B", staff_category: "admin", employment_type: "full_time")

      assert_nil Core::Access::StaffProfileScope.for(user_a, institution: institution)
    end
  end

  test "never returns a staff_member row from a DIFFERENT institution for the same global user" do
    institution_i = build_institution
    institution_j = build_institution

    user = within_tenant(institution_i) do
      u = Core::User.create!(email: "crossstaff@correo.test", name: "CrossStaff")
      institution_i.memberships.create!(user: u)
      u
    end
    within_tenant(institution_j) do
      iu = institution_j.memberships.create!(user: user)
      StaffManagement::StaffMember.create!(institution: institution_j, institution_user: iu,
        employee_number: "EMP-J", staff_category: "admin", employment_type: "full_time")
    end

    within_tenant(institution_i) do
      assert_nil Core::Access::StaffProfileScope.for(user, institution: institution_i)
    end
  end
end
