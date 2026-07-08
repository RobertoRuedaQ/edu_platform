# Per-request/per-job tenant context. ActiveSupport resets this automatically
# at the end of every executor cycle, so it cannot bleed between requests.
class Current < ActiveSupport::CurrentAttributes
  attribute :institution, :institution_id
  attribute :institution_user, :institution_user_id
  attribute :session

  # Request path assigns the record; keep institution_id in lock-step.
  # Job path (no record loaded) assigns institution_id directly.
  # Assigning the tenant may also let us resolve the membership (if a session is
  # already present); resolve_institution_user is safe to call in any order.
  def institution=(record)
    super
    self.institution_id = record&.id
    resolve_institution_user
  end

  # The membership the actor is acting through — the source of RBAC role
  # assignments. Kept in lock-step so either the record or the id can be set,
  # and so control_plane-style flows can still assign it directly.
  def institution_user=(record)
    super
    self.institution_user_id = record&.id
  end

  # The Core::Session backing this request. Assigning it lets us derive the
  # acting user and (with the tenant) the membership.
  def session=(record)
    super
    resolve_institution_user
  end

  # Derived from the session; nil when unauthenticated.
  def user = session&.user

  private

  # Resolve the membership from user + institution when BOTH are known. Safe to
  # call from either the institution= or session= setter regardless of which
  # runs first (idempotent, no-ops until both sides are present). The lookup
  # runs against the RLS-scoped institution_users, so it only ever returns the
  # current tenant's membership — exactly what the gate needs.
  #
  # Scoped to ACTIVE memberships: a suspended membership must lose every grant
  # on its very next request, not just be blocked from a future login — this
  # is the one seam that makes InstitutionUser#suspend! actually bite for an
  # already-open Core::Session, without having to hunt down and destroy it.
  def resolve_institution_user
    return if user.nil? || institution.nil?
    self.institution_user = user.memberships.active.find_by(institution_id: institution_id)
  end
end
