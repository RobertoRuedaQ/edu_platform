module Authorization
  # RETIRED from the runtime path as of P1: Authorization::Controller now
  # always builds IdentityAccess::PermissionCheck directly (never this class)
  # once that constant exists, which it always does. Kept only as a reference
  # for the record->Assignment mapping (from_records), which
  # IdentityAccess::PermissionCheck reimplements for itself rather than
  # depend on a class named "Stub" for real, security-critical resolution —
  # see that class for the real, fallback-free (R2) equivalent.
  module AssignmentSource
    module_function

    def for(institution_user_id:)
      from_records(institution_user_id).presence || StubAssignments.all
    end

    # Real grants mapped into Authorization::Assignment. Empty (-> falls back to
    # the stub) when there is no actor, the table is absent, or anything blows up.
    def from_records(institution_user_id)
      return [] if institution_user_id.blank?
      return [] unless IdentityAccess::RoleAssignment.table_exists?

      IdentityAccess::RoleAssignment
        .where(institution_user_id: institution_user_id)
        .includes(role: :permissions)
        .map do |ra|
          Assignment.new(
            role_key: ra.role.key,
            permission_keys: ra.role.permissions.map(&:key),
            scope_type: scope_type_for(ra),
            scope_id: scope_id_for(ra)
          )
        end
    rescue ActiveRecord::ActiveRecordError
      []
    end

    def scope_type_for(ra)
      return :institution if ra.institution_wide?
      return :department  if ra.scope_department_id
      return :grade_level if ra.scope_grade_level_id

      :group
    end

    def scope_id_for(ra)
      ra.scope_department_id || ra.scope_grade_level_id || ra.scope_group_id
    end
  end
end
