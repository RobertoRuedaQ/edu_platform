module ControlPlane
  # GLOBAL — a manual record that money arrived against an invoice (§ billing
  # hardening, OPEN_PROCESS.md #2). Prefixed control_plane_ on the table
  # because `payments` is already a real Finance table (tenant-scoped,
  # colegio<->familias) — a different domain entirely. No `status`: there is
  # no rail behind this beyond "someone with billing.manage typed it in", so
  # existence IS the only state worth modeling (never invent a state machine
  # without real behavior behind it).
  class Payment < ApplicationRecord
    self.table_name = "control_plane_payments"

    METHODS = %w[cash card transfer other].freeze

    belongs_to :invoice, class_name: "ControlPlane::Invoice"
    belongs_to :recorded_by, class_name: "ControlPlane::PlatformAdmin",
      foreign_key: :recorded_by_platform_admin_id, inverse_of: false

    delegate :institution, :billing_period, to: :invoice

    validates :amount_cents, numericality: { greater_than: 0 }
    validates :method, inclusion: { in: METHODS }
    validates :paid_on, presence: true

    # F6 — el único puente cents -> decimal, molde Activity#fee_amount.
    # BigDecimal exacto, nunca Float.
    def amount
      BigDecimal(amount_cents) / 100
    end
  end
end
