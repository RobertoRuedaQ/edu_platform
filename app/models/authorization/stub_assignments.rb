module Authorization
  # RETIRED from the runtime path as of P1: Authorization::AssignmentSource's
  # fallback to .all below is unreachable now that IdentityAccess::
  # PermissionCheck exists (see Authorization::Controller#build_authorization_
  # context) — no actor, real or not, is ever granted this persona anymore.
  # Kept only as a historical reference for the permission-key shape; nothing
  # in test/ seeds from it either (see test_helper.rb's grant_role!/with_grants,
  # which create real RoleAssignment rows instead).
  module StubAssignments
    module_function

    # Stub scope ids. Kept greppable; replaced by real section/department ids
    # once seeds + auth land. AssignmentSource prefers real rows over these.
    SECTION_ID    = "stub-section-9a".freeze
    DEPARTMENT_ID = "stub-department-humanities".freeze

    # A group director (homeroom) scoped to one section, plus a read grant across
    # their department — two scopes, enough to make scope-aware nav/dashboards
    # observable (they should see their section's students but not the school's).
    def all
      [
        Assignment.new(
          role_key: "group_director",
          permission_keys: %w[students.read grades.read grades.write counseling.read],
          scope_type: :group,
          scope_id: SECTION_ID
        ),
        Assignment.new(
          role_key: "area_head",
          permission_keys: %w[students.read staff.read],
          scope_type: :department,
          scope_id: DEPARTMENT_ID
        )
      ]
    end
  end
end
