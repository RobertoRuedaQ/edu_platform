require "test_helper"

class Core::Access::StaffRoleAssignmentsScopeTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "srs-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_user_with_membership!(institution, email:)
    user = Core::User.create!(email: email, name: "Persona #{email}")
    institution.memberships.create!(user: user)
    user
  end

  def grant!(institution, institution_user:, role_key:, scope_group_id: nil, valid_from: Date.current, valid_until: nil)
    role = IdentityAccess::Role.create!(institution: institution, key: "#{role_key}-#{SecureRandom.hex(2)}", name: role_key.humanize)
    IdentityAccess::RoleAssignment.create!(institution: institution, institution_user: institution_user, role: role,
      scope_group_id: scope_group_id, valid_from: valid_from, valid_until: valid_until)
  end

  test "returns only currently-effective assignments, excluding an expired one" do
    institution = build_institution

    within_tenant(institution) do
      user = build_user_with_membership!(institution, email: "t@correo.test")
      institution_user = institution.memberships.find_by(user: user)
      active = grant!(institution, institution_user: institution_user, role_key: "teacher")
      grant!(institution, institution_user: institution_user, role_key: "teacher_expired",
        valid_from: 60.days.ago.to_date, valid_until: 1.day.ago.to_date)

      result = Core::Access::StaffRoleAssignmentsScope.for(user, institution: institution)

      assert_equal [ active.id ], result.pluck(:id)
    end
  end

  test "never returns another person's assignments" do
    institution = build_institution

    within_tenant(institution) do
      user_a = build_user_with_membership!(institution, email: "a@correo.test")
      user_b = build_user_with_membership!(institution, email: "b@correo.test")
      iu_b = institution.memberships.find_by(user: user_b)
      grant!(institution, institution_user: iu_b, role_key: "teacher")

      result = Core::Access::StaffRoleAssignmentsScope.for(user_a, institution: institution)
      assert_empty result
    end
  end

  test "never returns assignments from a DIFFERENT institution for the same global user" do
    institution_i = build_institution
    institution_j = build_institution

    user = within_tenant(institution_i) { build_user_with_membership!(institution_i, email: "cross@correo.test") }
    within_tenant(institution_j) do
      iu = institution_j.memberships.create!(user: user)
      grant!(institution_j, institution_user: iu, role_key: "teacher")
    end

    within_tenant(institution_i) do
      result = Core::Access::StaffRoleAssignmentsScope.for(user, institution: institution_i)
      assert_empty result, "an assignment from institution J leaked while acting in institution I"
    end
  end

  test "returns a composable ActiveRecord::Relation" do
    institution = build_institution
    within_tenant(institution) do
      user = build_user_with_membership!(institution, email: "rel@correo.test")
      assert_kind_of ActiveRecord::Relation, Core::Access::StaffRoleAssignmentsScope.for(user, institution: institution)
    end
  end

  test "returns an empty relation for a nil user or institution, never an error" do
    institution = build_institution
    within_tenant(institution) do
      user = build_user_with_membership!(institution, email: "nilcheck@correo.test")
      assert_empty Core::Access::StaffRoleAssignmentsScope.for(nil, institution: institution)
      assert_empty Core::Access::StaffRoleAssignmentsScope.for(user, institution: nil)
    end
  end

  test "accepts no search term — the interface itself has no such parameter" do
    accepted_keywords = Core::Access::StaffRoleAssignmentsScope.method(:for).parameters.map(&:last)
    assert_not_includes accepted_keywords, :q
    assert_not_includes accepted_keywords, :term
  end
end
