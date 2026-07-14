module Authorization
  # ONE scoped grant. Deliberately mirrors IdentityAccess::RoleAssignment's shape
  # (a role's permission keys + a single scope) so swapping the stub for the real
  # IdentityAccess::PermissionCheck is a mechanical 1:1 change.
  #
  # scope_type: :institution | :department | :grade_level | :group | :route
  #   (:group == section; :route == a transportation route — added for
  #   driver/route_monitor's "own route", which is neither a department, a
  #   grade level, nor a school section)
  Assignment = Data.define(:role_key, :permission_keys, :scope_type, :scope_id) do
    # How a resource exposes the id for each scoped grant type. A resource is
    # "covered" when its scope id matches the grant's. institution-wide grants
    # never consult these (they cover everything).
    SCOPE_READERS = {
      department:  :department_id,
      grade_level: :grade_level_id,
      group:       :group_id,
      route:       :route_id
    }.freeze

    def grants?(permission_key)
      permission_keys.map(&:to_s).include?(permission_key.to_s)
    end

    # institution-wide covers everything; a capability-only check (resource nil)
    # passes on scope because scoping a LIST is the Query object's job, not the
    # gate's; otherwise the resource must sit inside this grant's scope.
    def covers?(resource)
      return true if scope_type == :institution
      return true if resource.nil?

      reader = SCOPE_READERS.fetch(scope_type) { return false }
      resource.respond_to?(reader) && resource.public_send(reader).to_s == scope_id.to_s
    end
  end
end
