require "test_helper"

class IdentityAccessTest < ActionDispatch::IntegrationTest
  setup { @user, @institution = sign_in_as_member }

  def as_institution_admin(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[roles.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "users index/show require roles.manage" do
    with_grants { get "/identity_access/users"; assert_response :forbidden }

    as_institution_admin do
      get "/identity_access/users"
      assert_response :success
      assert_select ".identity-card__name", text: "Laura Gómez Duarte"

      get "/identity_access/users/iu-1"
      assert_response :success
    end
  end

  test "roles index renders the catalog and the full permission matrix" do
    as_institution_admin do
      get "/identity_access/roles"
      assert_response :success
      assert_select "a", text: "Docente"
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

  # --- the real validation: assignable_scope_types is enforced, not cosmetic -

  test "create rejects a role assigned outside its assignable scope types" do
    as_institution_admin do
      # role-2 = teacher, assignable_scope_types: [:group] — no scope submitted
      # defaults to :institution, which teacher does NOT admit.
      post "/identity_access/assignments", params: { assignment: { role_id: "role-2" } }
      assert_response :unprocessable_entity
      assert_match(/no admite el alcance/, flash[:alert].to_s)
    end
  end

  test "create rejects institution_admin (institution-only) when a group scope is submitted" do
    as_institution_admin do
      post "/identity_access/assignments",
        params: { assignment: { role_id: "role-1", scope_group_id: "stub-section-9a" } }
      assert_response :unprocessable_entity
    end
  end

  test "create succeeds when the submitted scope matches the role's assignable types" do
    as_institution_admin do
      # role-2 = teacher, assignable_scope_types: [:group] — group scope submitted.
      post "/identity_access/assignments",
        params: { assignment: { role_id: "role-2", scope_group_id: "stub-section-9a" } }
      assert_redirected_to identity_access_assignments_path
    end
  end

  test "create succeeds for institution_admin with no scope (institution-wide is its own admissible type)" do
    as_institution_admin do
      post "/identity_access/assignments", params: { assignment: { role_id: "role-1" } }
      assert_redirected_to identity_access_assignments_path
    end
  end
end
