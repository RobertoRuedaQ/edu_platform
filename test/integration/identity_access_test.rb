require "test_helper"

class IdentityAccessTest < ActionDispatch::IntegrationTest
  def within_tenant(&block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      block.call
    end
  end

  setup { @user, @institution = sign_in_as_member }

  def as_institution_admin(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[roles.manage people.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # find_or_create_by! — as_institution_admin's own with_grants/grant_role!
  # already creates a real "institution_admin" Role as a side effect of
  # granting the actor their own permissions, so re-requesting that same
  # key here must reuse it, never collide on the unique (institution, key).
  # Forces name/system to match what THIS test needs, regardless of
  # whatever the grant helper already set — RBAC itself only cares about
  # RolePermission/RoleAssignment rows, never the system flag, so adjusting
  # it here never perturbs the actor's own grant.
  def build_role(key:, name: key.humanize, system: false)
    within_tenant do
      role = IdentityAccess::Role.find_or_create_by!(institution: @institution, key: key) do |r|
        r.name = name
        r.system = system
      end
      role.update!(name: name, system: system)
      role
    end
  end

  def build_target_person(email: "target-#{SecureRandom.hex(4)}@member.test")
    within_tenant do
      user = Core::User.create!(email: email, name: "Persona Objetivo", password: "password-123456")
      @institution.memberships.create!(user: user)
      user
    end
  end

  def build_group
    within_tenant do
      GroupManagement::Section.create!(institution: @institution, name: "9A", academic_year: Date.current.year)
    end
  end

  test "users index/show require roles.manage" do
    target = build_target_person
    with_grants { get "/identity_access/users"; assert_response :forbidden }

    as_institution_admin do
      get "/identity_access/users"
      assert_response :success
      assert_match target.name, response.body

      get "/identity_access/users/#{target.id}"
      assert_response :success
    end
  end

  test "roles index renders the catalog and the full permission matrix" do
    as_institution_admin do
      get "/identity_access/roles"
      assert_response :success
      assert_select ".permission-matrix code", text: "roles.manage"
      # institution_admin grants roles.manage -> that cell is marked granted.
      assert_select ".permission-matrix__state.is-granted", minimum: 1
    end
  end

  test "an actor with no grants is denied roles/users/assignments (403)" do
    with_grants do
      get "/identity_access/roles"
      assert_response :forbidden
    end
  end

  test "creating a role persists real Role + RolePermission rows" do
    as_institution_admin do
      permission = within_tenant { IdentityAccess::Permission.find_or_create_by!(key: "students.read") { |p| p.description = "x" } }

      assert_difference -> { IdentityAccess::Role.count }, 1 do
        post "/identity_access/roles", params: { role: { name: "Bibliotecario", description: "Presta libros",
          permission_ids: [ permission.id ] } }
      end
      role = within_tenant { IdentityAccess::Role.find_by(institution_id: @institution.id, name: "Bibliotecario") }
      assert_redirected_to identity_access_role_path(role)
      assert_equal [ "students.read" ], within_tenant { role.permissions.pluck(:key) }
      assert_not role.system?
    end
  end

  test "editing a role re-syncs its permissions" do
    as_institution_admin do
      role = build_role(key: "custom_role")
      perm_a = within_tenant { IdentityAccess::Permission.find_or_create_by!(key: "students.read") { |p| p.description = "x" } }
      perm_b = within_tenant { IdentityAccess::Permission.find_or_create_by!(key: "grades.read") { |p| p.description = "x" } }
      within_tenant { IdentityAccess::RolePermission.create!(institution: @institution, role: role, permission: perm_a) }

      patch "/identity_access/roles/#{role.id}", params: { role: { name: role.name, permission_ids: [ perm_b.id ] } }

      assert_redirected_to identity_access_role_path(role)
      assert_equal [ "grades.read" ], within_tenant { role.reload.permissions.pluck(:key) }
    end
  end

  test "system roles reject edit" do
    as_institution_admin do
      role = build_role(key: "institution_admin", name: "Administrador de institución", system: true)

      get "/identity_access/roles/#{role.id}/edit"
      assert_redirected_to identity_access_role_path(role)

      patch "/identity_access/roles/#{role.id}", params: { role: { name: "Hackeado" } }
      assert_redirected_to identity_access_role_path(role)
      assert_equal "Administrador de institución", within_tenant { role.reload.name }
    end
  end

  # --- the real validation: assignable_scope_types is enforced, not cosmetic -

  test "create rejects a role assigned outside its assignable scope types" do
    as_institution_admin do
      target = build_target_person
      role = build_role(key: "teacher", name: "Docente") # assignable_scope_types: [:group]

      post "/identity_access/assignments", params: { user_id: target.id, assignment: { role_id: role.id } }
      assert_response :unprocessable_entity
      assert_match(/no admite el alcance/, flash[:alert].to_s)
    end
  end

  test "create rejects institution_admin (institution-only) when a group scope is submitted" do
    as_institution_admin do
      target = build_target_person
      role = build_role(key: "institution_admin", name: "Administrador de institución")
      group = build_group

      post "/identity_access/assignments",
        params: { user_id: target.id, assignment: { role_id: role.id, scope_group_id: group.id } }
      assert_response :unprocessable_entity
    end
  end

  test "create succeeds when the submitted scope matches the role's assignable types" do
    as_institution_admin do
      target = build_target_person
      role = build_role(key: "teacher", name: "Docente")
      group = build_group

      assert_difference -> { IdentityAccess::RoleAssignment.count }, 1 do
        post "/identity_access/assignments",
          params: { user_id: target.id, assignment: { role_id: role.id, scope_group_id: group.id } }
      end
      assert_redirected_to identity_access_assignments_path
    end
  end

  test "create succeeds for institution_admin with no scope (institution-wide is its own admissible type)" do
    as_institution_admin do
      target = build_target_person
      role = build_role(key: "institution_admin", name: "Administrador de institución")

      post "/identity_access/assignments", params: { user_id: target.id, assignment: { role_id: role.id } }
      assert_redirected_to identity_access_assignments_path
    end
  end

  test "a custom role (not in the canonical catalog) admits any scope" do
    as_institution_admin do
      target = build_target_person
      role = build_role(key: "librarian_custom", name: "Bibliotecario")
      group = build_group

      post "/identity_access/assignments",
        params: { user_id: target.id, assignment: { role_id: role.id, scope_group_id: group.id } }
      assert_redirected_to identity_access_assignments_path
    end
  end

  test "a duplicate grant (same person+role+scope) is rejected gracefully, never a 500" do
    as_institution_admin do
      target = build_target_person
      role = build_role(key: "institution_admin", name: "Administrador de institución")

      post "/identity_access/assignments", params: { user_id: target.id, assignment: { role_id: role.id } }
      assert_redirected_to identity_access_assignments_path

      assert_no_difference -> { IdentityAccess::RoleAssignment.count } do
        post "/identity_access/assignments", params: { user_id: target.id, assignment: { role_id: role.id } }
      end
      assert_response :unprocessable_entity
      assert_match(/ya tiene ese rol/, flash[:alert].to_s)
    end
  end

  # --- B2: opt-in coupling to academic_terms -------------------------------

  test "closing a term opted-in caps valid_until at the term's ends_on, only for still-open assignments" do
    target = build_target_person
    role = build_role(key: "institution_admin", name: "Administrador de institución")
    term = within_tenant do
      Core::AcademicTerm.create!(institution: @institution, code: "2027-1", name: "2027-1",
        starts_on: 1.month.ago, ends_on: 1.month.from_now, status: "active")
    end
    assignment_with_manual_expiry = within_tenant do
      other_person = Core::User.create!(email: "manual-#{SecureRandom.hex(4)}@member.test", name: "Otro",
        password: "password-123456")
      other_membership = @institution.memberships.create!(user: other_person)
      IdentityAccess::RoleAssignment.create!(institution: @institution, institution_user: other_membership,
        role: role, academic_term: term, valid_until: 3.days.from_now.to_date)
    end

    as_institution_admin_for_terms do
      post "/identity_access/assignments",
        params: { user_id: target.id, assignment: { role_id: role.id, academic_term_id: term.id } }
      assert_redirected_to identity_access_assignments_path

      assignment = within_tenant { IdentityAccess::RoleAssignment.find_by(institution_user: @institution.memberships.find_by(user_id: target.id)) }
      assert_nil assignment.valid_until

      post "/core/academic_terms/#{term.id}/close"

      assert_equal term.ends_on, within_tenant { assignment.reload.valid_until }
      assert_equal 3.days.from_now.to_date, within_tenant { assignment_with_manual_expiry.reload.valid_until }
    end
  end

  def as_institution_admin_for_terms(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin",
        permission_keys: %w[roles.manage people.manage academic_terms.manage],
        scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # --- P2: institution_users.role filter + self-service display -----------

  test "people index filters by institution_users.role" do
    within_tenant do
      guardian_user = Core::User.create!(email: "guardian-filter-#{SecureRandom.hex(4)}@example.test", name: "Acudiente")
      @institution.memberships.create!(user: guardian_user, role: "guardian")
    end

    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[people.manage],
                                     scope_type: :institution, scope_id: nil)
    ) do
      get "/identity_access/people", params: { role: "guardian" }
      assert_response :success
      assert_match "Acudiente", response.body
      assert_no_match "Test Member", response.body
    end
  end

  test "self-service shows the account's institution_users.role" do
    get "/mis_datos"
    assert_response :success
    assert_match(/Rol de cuenta.*Member/m, response.body)
  end
end
