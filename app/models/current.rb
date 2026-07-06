# Per-request/per-job tenant context. ActiveSupport resets this automatically
# at the end of every executor cycle, so it cannot bleed between requests.
class Current < ActiveSupport::CurrentAttributes
  attribute :institution, :institution_id

  # Request path assigns the record; keep institution_id in lock-step.
  # Job path (no record loaded) assigns institution_id directly.
  def institution=(record)
    super
    self.institution_id = record&.id
  end
end
