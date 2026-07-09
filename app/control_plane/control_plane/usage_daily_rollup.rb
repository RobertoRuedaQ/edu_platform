module ControlPlane
  # GLOBAL — one (institution, addon, unit, usage_date) bucket. Unlike
  # UsageEvent, rollups ARE recomputed in place (G4) — ControlPlane::Usage::
  # RollupJob upserts this row every time it runs for a given day, so
  # re-running is always safe and never duplicates or double-counts. S4's
  # period cutoff sums THESE rows, never usage_events directly.
  class UsageDailyRollup < ApplicationRecord
    self.table_name = "usage_daily_rollups"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :addon, class_name: "ControlPlane::Addon"

    validates :unit, presence: true
    validates :usage_date, presence: true
    validates :total_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
    validates :event_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
    validates :unit, uniqueness: { scope: %i[institution_id addon_id usage_date] }

    scope :for_institution, ->(institution) { where(institution_id: institution.id) }
    scope :most_recent_first, -> { order(usage_date: :desc) }
  end
end
