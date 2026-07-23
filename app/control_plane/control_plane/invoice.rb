module ControlPlane
  # GLOBAL — a DRAFT invoice for a period, NEVER auto-emitted (§7.3). The
  # period cut (ControlPlane::Billing::PeriodCut) creates/regenerates this;
  # finalizing is a manual, audited platform_admin action, and finalizing is
  # NOT charging — there is no automatic payment gateway in v1, but a manual
  # payment CAN be recorded against it (see ControlPlane::Payment).
  #
  # institution_id/subscription_id are plain FKs to global tables, never RLS
  # scope. subscription_id is provenance only (nullable) — the invoice's own
  # currency/lines are what matter once cut. billing_period_id is the real
  # anchor for "which period" — period_start/period_end below are delegated
  # reads so the 3 existing views + 1 form never had to change a line.
  class Invoice < ApplicationRecord
    self.table_name = "invoices"

    InvalidTransition = Class.new(StandardError)

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :subscription, class_name: "ControlPlane::Subscription", optional: true
    belongs_to :billing_period, class_name: "ControlPlane::BillingPeriod"
    has_many :line_items, class_name: "ControlPlane::InvoiceLineItem",
      foreign_key: :invoice_id, inverse_of: :invoice, dependent: :destroy
    has_many :payments, class_name: "ControlPlane::Payment", dependent: :restrict_with_exception

    delegate :starts_on, :ends_on, to: :billing_period, prefix: false
    alias_method :period_start, :starts_on
    alias_method :period_end, :ends_on

    validates :currency, presence: true, length: { is: 3 }
    validates :status, inclusion: { in: %w[draft finalized void] }
    validates :subtotal_cents, numericality: { greater_than_or_equal_to: 0 }
    validate :one_non_void_invoice_per_period

    scope :draft, -> { where(status: "draft") }
    scope :finalized, -> { where(status: "finalized") }
    scope :void, -> { where(status: "void") }
    scope :for_institution, ->(institution) { where(institution_id: institution.id) }
    scope :most_recent_first, -> { joins(:billing_period).order("billing_periods.starts_on DESC") }

    def draft? = status == "draft"
    def finalized? = status == "finalized"
    def void? = status == "void"

    # Computado, nunca persistido (molde Loan#overdue?) — un pago manual
    # nuevo se refleja de inmediato sin tocar esta fila.
    def paid_cents
      payments.sum(:amount_cents)
    end

    def balance_due_cents
      subtotal_cents - paid_cents
    end

    # F6 — puente cents -> decimal, molde Activity#fee_amount. BigDecimal
    # exacto, nunca Float.
    def paid_amount
      BigDecimal(paid_cents) / 100
    end

    def balance_due_amount
      BigDecimal(balance_due_cents) / 100
    end

    def recompute_subtotal!
      update!(subtotal_cents: line_items.sum(:amount_cents))
    end

    # Only from draft — a finalized/void invoice's numbers are frozen for good.
    def finalize!
      raise InvalidTransition, "solo un borrador puede finalizarse" unless draft?
      recompute_subtotal!
      update!(status: "finalized", finalized_at: Time.current)
    end

    def void!
      raise InvalidTransition, "una factura finalizada no puede anularse" if finalized?
      update!(status: "void")
    end

    private

    def one_non_void_invoice_per_period
      return if billing_period_id.nil? || status == "void"

      scope = Invoice.where(billing_period_id: billing_period_id).where.not(status: "void")
      scope = scope.where.not(id: id) if persisted?
      errors.add(:base, "ya existe una factura no anulada para este periodo") if scope.exists?
    end
  end
end
