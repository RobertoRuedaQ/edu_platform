module IdentityAccess
  # THE real seam (P1): resolves "¿puede el actor U ejecutar el permiso P sobre
  # el recurso R?" from REAL role_assignments (tenant-scoped, read under the
  # request's GUC) -> roles -> role_permissions -> the global permissions
  # catalog. Real-only, fail-closed (R2): no RoleAssignment that applies means
  # ZERO permissions — there is no fallback to any stub persona here, and none
  # should ever be added back. A nil institution_user_id (no active membership
  # — e.g. suspended, R3) also yields zero permissions, for free, since there
  # is simply nothing to load.
  #
  # Reuses Authorization::Assignment as the in-memory grant shape (institution-
  # wide/nil-resource bypass, SCOPE_READERS descriptor convention) so the
  # scope-covering logic isn't duplicated — only WHERE the grants come from
  # changes versus the retired Authorization::StubResolver/StubAssignments
  # path (kept only as test-seeding history, never consulted at runtime once
  # this class exists — see Authorization::Controller#build_authorization_context).
  #
  # Resolved ONCE per request (memoized here; Authorization::Controller builds
  # one instance per request and reuses it for every authorize!/can? call — R4).
  class PermissionCheck
    def self.for(institution_user_id:)
      new(institution_user_id: institution_user_id)
    end

    def initialize(institution_user_id:)
      @institution_user_id = institution_user_id
    end

    # HARD/COSMETIC gate entry point — same signature as Authorization::StubResolver#can?.
    def can?(permission_key, resource = nil)
      assignments.any? { |a| a.grants?(permission_key) && a.covers?(resource) }
    end

    # Scope restrictions the actor holds for permission_key, for a domain's
    # Query object to filter an index directly instead of loading every row
    # and calling can? per row (both are equivalent — see
    # TeacherManagement::TeacherScope for the per-row style, still valid).
    # Adoption is incremental per domain (R7) — this exists so a domain CAN
    # switch to it without changing the engine.
    def scope_for(permission_key)
      relevant = assignments.select { |a| a.grants?(permission_key) }
      return Scope::INSTITUTION_WIDE if relevant.any? { |a| a.scope_type == :institution }

      Scope.new(
        department_ids:  ids_for(relevant, :department),
        grade_level_ids: ids_for(relevant, :grade_level),
        group_ids:       ids_for(relevant, :group),
        route_ids:       ids_for(relevant, :route)
      )
    end

    # Restrictions returned by scope_for. institution_wide? true means "covers
    # everything" — a domain's Query object should skip filtering entirely
    # rather than trying to enumerate every possible id.
    Scope = Data.define(:department_ids, :grade_level_ids, :group_ids, :route_ids) do
      def institution_wide? = false
    end
    Scope::INSTITUTION_WIDE = Data.define(:institution_wide?).new(institution_wide?: true).freeze

    private

    def ids_for(assignments, scope_type)
      assignments.select { |a| a.scope_type == scope_type }.map(&:scope_id)
    end

    def assignments
      @assignments ||= load_assignments
    end

    # Empty when there's no actor (blank institution_user_id — including a
    # suspended/inactive membership, which Current never resolves in the
    # first place, R3) or no RoleAssignment rows apply. Never rescues/falls
    # back — a real error here should surface, not silently degrade grants.
    def load_assignments
      return [] if @institution_user_id.blank?

      IdentityAccess::RoleAssignment
        .where(institution_user_id: @institution_user_id)
        .effective_now
        .includes(role: :permissions)
        .map do |ra|
          Authorization::Assignment.new(
            role_key: ra.role.key,
            permission_keys: ra.role.permissions.map(&:key),
            scope_type: scope_type_for(ra),
            scope_id: scope_id_for(ra)
          )
        end
    end

    def scope_type_for(ra)
      return :institution if ra.institution_wide?
      return :department  if ra.scope_department_id
      return :grade_level  if ra.scope_grade_level_id
      return :route        if ra.scope_route_id

      :group
    end

    def scope_id_for(ra)
      ra.scope_department_id || ra.scope_grade_level_id || ra.scope_group_id || ra.scope_route_id
    end
  end
end
