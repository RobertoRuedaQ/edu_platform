require "test_helper"

class IdentityAccess::PermissionCheckTest < ActiveSupport::TestCase
  setup do
    @institution = Core::Institution.create!(name: "Colegio PermissionCheck", slug: "pc-#{SecureRandom.hex(4)}",
      code: "PC-#{SecureRandom.hex(3)}", kind: "school")
    @user = Core::User.create!(email: "pc-#{SecureRandom.hex(4)}@test.example", name: "Actor de Prueba",
      password: "password-123456")
    within_tenant { @institution_user = @institution.memberships.create!(user: @user) }
  end

  def within_tenant(&block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      block.call
    end
  end

  def seed_role(key:, permission_keys:)
    within_tenant do
      role = IdentityAccess::Role.create!(institution: @institution, key: key, name: key.humanize)
      Array(permission_keys).each do |pkey|
        permission = IdentityAccess::Permission.find_or_create_by!(key: pkey)
        IdentityAccess::RolePermission.create!(institution: @institution, role: role, permission: permission)
      end
      role
    end
  end

  def assign!(role:, scope_attrs: {}, valid_from: Date.current, valid_until: nil)
    within_tenant do
      IdentityAccess::RoleAssignment.create!(
        institution: @institution, institution_user: @institution_user, role: role,
        valid_from: valid_from, valid_until: valid_until, **scope_attrs
      )
    end
  end

  ScopedResource = Struct.new(:department_id, :group_id, :grade_level_id)

  # --- R2: real-only, fail-closed --------------------------------------------

  test "no institution_user_id (blank actor) yields zero permissions" do
    check = IdentityAccess::PermissionCheck.for(institution_user_id: nil)
    assert_not check.can?("students.read")
  end

  test "an institution_user with no RoleAssignment at all is denied everything" do
    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert_not check.can?("students.read")
    assert_not check.can?("students.read", ScopedResource.new("dept-1", nil, nil))
  end

  # --- real institution-wide / scoped grants ----------------------------------

  test "an institution-wide grant covers any resource" do
    role = seed_role(key: "institution_admin", permission_keys: %w[students.read])
    assign!(role: role)

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert check.can?("students.read")
    assert check.can?("students.read", ScopedResource.new("whatever", nil, nil))
  end

  test "a department-scoped grant covers a resource in that department and denies others" do
    department = within_tenant { StaffManagement::Department.create!(institution: @institution, name: "Matemáticas", code: "MAT", kind: "academic") }
    other_department = within_tenant { StaffManagement::Department.create!(institution: @institution, name: "Sociales", code: "SOC", kind: "academic") }
    role = seed_role(key: "area_lead", permission_keys: %w[teacher.evaluate])
    assign!(role: role, scope_attrs: { scope_department_id: department.id })

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert check.can?("teacher.evaluate", ScopedResource.new(department.id, nil, nil))
    assert_not check.can?("teacher.evaluate", ScopedResource.new(other_department.id, nil, nil))
  end

  test "a permission the actor was never granted is denied even inside their scope" do
    department = within_tenant { StaffManagement::Department.create!(institution: @institution, name: "Matemáticas", code: "MAT", kind: "academic") }
    role = seed_role(key: "area_lead", permission_keys: %w[teacher.evaluate])
    assign!(role: role, scope_attrs: { scope_department_id: department.id })

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert_not check.can?("finance.write", ScopedResource.new(department.id, nil, nil))
  end

  # --- R6: scope-indeterminable resource --------------------------------------

  test "a resource without the matching scope descriptor is not covered by a scoped grant" do
    department = within_tenant { StaffManagement::Department.create!(institution: @institution, name: "Matemáticas", code: "MAT", kind: "academic") }
    role = seed_role(key: "area_lead", permission_keys: %w[teacher.evaluate])
    assign!(role: role, scope_attrs: { scope_department_id: department.id })

    resource_without_department_id = Struct.new(:group_id).new("some-group")
    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert_not check.can?("teacher.evaluate", resource_without_department_id)
  end

  test "a resource without any scope descriptor IS covered by an institution-wide grant" do
    role = seed_role(key: "institution_admin", permission_keys: %w[teacher.evaluate])
    assign!(role: role)

    resource_without_any_descriptor = Object.new
    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert check.can?("teacher.evaluate", resource_without_any_descriptor)
  end

  # --- R5: dating --------------------------------------------------------------

  test "an assignment past its valid_until no longer covers" do
    role = seed_role(key: "teacher", permission_keys: %w[grades.write])
    assign!(role: role, valid_from: 30.days.ago.to_date, valid_until: 1.day.ago.to_date)

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert_not check.can?("grades.write")
  end

  test "an assignment not yet valid_from does not cover" do
    role = seed_role(key: "teacher", permission_keys: %w[grades.write])
    assign!(role: role, valid_from: 1.day.from_now.to_date)

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert_not check.can?("grades.write")
  end

  test "an open-ended assignment (nil valid_until) covers indefinitely" do
    role = seed_role(key: "teacher", permission_keys: %w[grades.write])
    assign!(role: role, valid_from: 1.year.ago.to_date, valid_until: nil)

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert check.can?("grades.write")
  end

  # --- scope_for ---------------------------------------------------------------

  test "scope_for reports institution_wide? true for an institution-wide grant" do
    role = seed_role(key: "institution_admin", permission_keys: %w[students.read])
    assign!(role: role)

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    assert check.scope_for("students.read").institution_wide?
  end

  test "scope_for collects the scoped ids the actor holds for a permission" do
    department = within_tenant { StaffManagement::Department.create!(institution: @institution, name: "Matemáticas", code: "MAT", kind: "academic") }
    role = seed_role(key: "area_lead", permission_keys: %w[teacher.evaluate])
    assign!(role: role, scope_attrs: { scope_department_id: department.id })

    check = IdentityAccess::PermissionCheck.for(institution_user_id: @institution_user.id)
    scope = check.scope_for("teacher.evaluate")
    assert_not scope.institution_wide?
    assert_equal [ department.id ], scope.department_ids
    assert_equal [], scope.group_ids
  end
end
