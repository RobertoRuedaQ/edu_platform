module Authorization
  # Stub permission resolver. Answers can?(permission_key, resource) by matching
  # the actor's grants against the requested capability AND (when a resource is
  # given) the grant's scope. This is the SAME interface the real
  # IdentityAccess::PermissionCheck will expose, so the controller seam swaps 1:1.
  #
  # TODO: reemplazar por IdentityAccess::PermissionCheck real.
  class StubResolver
    def initialize(assignments)
      @assignments = Array(assignments)
    end

    # Read-only, never raises, always returns a boolean. Used by both the hard
    # gate (authorize!) and the cosmetic view helper (can?).
    def can?(permission_key, resource = nil)
      @assignments.any? { |a| a.grants?(permission_key) && a.covers?(resource) }
    end
  end
end
