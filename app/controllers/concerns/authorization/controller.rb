module Authorization
  # Controller-side authorization: the HARD gate.
  #
  #   authorize!(key, resource) is the REAL protection — call it in every action
  #     that needs one. It raises Authorization::NotAuthorized (-> friendly 403).
  #   can?(key, resource) is COSMETIC ONLY — for show/hide in views. NEVER guard
  #     data access or actions with it; the controller is the boundary.
  #
  # Grants are resolved ONCE per request. P1: IdentityAccess::PermissionCheck
  # now always exists, so build_authorization_context always takes the real
  # branch below — the StubResolver/AssignmentSource/StubAssignments fallback
  # is dead code at runtime (kept only as test-seeding history; StubResolver
  # itself is still directly useful as a fixed in-memory context for tests
  # that can't seed a real RoleAssignment — see test_helper.rb's
  # with_raw_grants). Real-only, fail-closed: no RoleAssignment that applies
  # means zero permissions, never the old stub persona.
  #
  # NOTE: named ::Controller (not plain Authorization) so the controller concern
  # and the Authorization model namespace never collide under Zeitwerk.
  module Controller
    extend ActiveSupport::Concern

    included do
      helper_method :can?
      rescue_from Authorization::NotAuthorized, with: :deny_access
    end

    private

    # HARD GATE. Raises (-> 403) when the actor lacks the permission for resource.
    def authorize!(permission_key, resource = nil)
      return if authorization_context.can?(permission_key, resource)

      raise Authorization::NotAuthorized.new(permission_key)
    end

    # COSMETIC. Safe boolean for views (show/hide). NOT protection — see above.
    def can?(permission_key, resource = nil)
      authorization_context.can?(permission_key, resource)
    end

    # Resolved once per request; every can?/authorize! in the action reuses it.
    def authorization_context
      @authorization_context ||= build_authorization_context
    end

    def build_authorization_context
      if defined?(IdentityAccess::PermissionCheck)
        IdentityAccess::PermissionCheck.for(institution_user_id: Current.institution_user_id)
      else
        # Unreachable once identity_access/services/permission_check.rb exists
        # (Zeitwerk always resolves the constant) — kept only so this concern
        # doesn't hard-depend on that file's presence at parse time.
        Authorization::StubResolver.new(
          Authorization::AssignmentSource.for(institution_user_id: Current.institution_user_id)
        )
      end
    end

    # Friendly 403. HTML gets the page; API/other formats get a bare status.
    def deny_access(_exception)
      respond_to do |format|
        format.html { render "errors/forbidden", status: :forbidden }
        format.any  { head :forbidden }
      end
    end
  end
end
