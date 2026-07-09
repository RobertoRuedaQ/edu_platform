module ControlPlane
  # GLOBAL, append-only fact: an addon-metered event happened. institution_id/
  # addon_id are plain FKs to global tables, never RLS scope — this pipe is
  # domain-agnostic and NEVER fixes a tenant GUC (G6). Only ever created via
  # ControlPlane::Usage::Ingest, never edited — `readonly?` allows the initial
  # insert (record not yet persisted) but blocks any update/destroy once
  # written, backstopping the append-only design at the AR layer too (no
  # `updated_at` column at all, matching the migration).
  class UsageEvent < ApplicationRecord
    self.table_name = "usage_events"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :addon, class_name: "ControlPlane::Addon"

    validates :unit, presence: true
    validates :quantity, numericality: { greater_than: 0, only_integer: true }
    validates :occurred_at, presence: true
    validates :idempotency_key, presence: true,
      uniqueness: { scope: %i[institution_id addon_id] }

    scope :for_institution_and_addon, ->(institution, addon) {
      where(institution_id: institution.id, addon_id: addon.id)
    }
    scope :on_date, ->(date) { where(occurred_at: date.all_day) }

    def readonly?
      persisted?
    end
  end
end
