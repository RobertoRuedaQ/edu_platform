# Per-request/per-job tenant context. ActiveSupport resets this automatically
# at the end of every executor cycle, so it cannot bleed between requests.
class Current < ActiveSupport::CurrentAttributes
  attribute :institution, :institution_id
  attribute :institution_user, :institution_user_id

  # Request path assigns the record; keep institution_id in lock-step.
  # Job path (no record loaded) assigns institution_id directly.
  def institution=(record)
    super
    self.institution_id = record&.id
  end

  # The membership the actor is acting through — the source of RBAC role
  # assignments. No auth is wired yet, so this stays nil in this phase and the
  # gate falls back to Authorization::StubAssignments. Kept in lock-step like
  # institution so the real auth layer can assign either the record or the id.
  def institution_user=(record)
    super
    self.institution_user_id = record&.id
  end
end
