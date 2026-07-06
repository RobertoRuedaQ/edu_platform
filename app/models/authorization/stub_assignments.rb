module Authorization
  # The signed-in actor's grants for this views-only phase, used ONLY when no
  # real IdentityAccess::RoleAssignment rows exist yet (no auth/seeds wired).
  # Permission keys are the REAL ones from IdentityAccess::SeedPermissions::CATALOG
  # so the gate and nav exercise real capabilities, not invented strings.
  #
  # TODO: reemplazar por las asignaciones reales del usuario autenticado.
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
