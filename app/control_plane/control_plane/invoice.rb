module ControlPlane
  # GLOBAL — a DRAFT invoice for a period, NEVER auto-emitted (§7.3). The
  # period cut (ControlPlane::Billing::PeriodCut) creates/regenerates this;
  # finalizing is a manual, audited platform_admin action, and finalizing is
  # NOT charging — there is no payment rail in v1.
  #
  # institution_id/subscription_id are plain FKs to global tables, never RLS
  # scope. subscription_id is provenance only (nullable) — the invoice's own
  # currency/lines are what matter once cut.
  class Invoice < ApplicationRecord
    self.table_name = "invoices"

    InvalidTransition = Class.new(StandardError)

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :subscription, class_name: "ControlPlane::Subscription", optional: true
    has_many :line_items, class_name: "ControlPlane::InvoiceLineItem",
      foreign_key: :invoice_id, inverse_of: :invoice, dependent: :destroy

    validates :period_start, :period_end, :currency, presence: true
    validates :currency, length: { is: 3 }
    validates :status, inclusion: { in: %w[draft finalized void] }
    validates :subtotal_cents, numericality: { greater_than_or_equal_to: 0 }
    validate :period_end_after_or_equal_start
    validate :one_non_void_invoice_per_period

    scope :draft, -> { where(status: "draft") }
    scope :finalized, -> { where(status: "finalized") }
    scope :void, -> { where(status: "void") }
    scope :for_institution, ->(institution) { where(institution_id: institution.id) }
    scope :most_recent_first, -> { order(period_start: :desc) }

    def draft? = status == "draft"
    def finalized? = status == "finalized"
    def void? = status == "void"

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

    def period_end_after_or_equal_start
      return if period_start.nil? || period_end.nil?
      errors.add(:period_end, "debe ser igual o posterior al inicio del periodo") if period_end < period_start
    end

    def one_non_void_invoice_per_period
      return if institution_id.nil? || period_start.nil? || period_end.nil? || status == "void"

      scope = Invoice.where(institution_id: institution_id, period_start: period_start, period_end: period_end)
        .where.not(status: "void")
      scope = scope.where.not(id: id) if persisted?
      errors.add(:base, "ya existe una factura no anulada para este periodo") if scope.exists?
    end
  end
end
