module Finance
  # THE single read path for "what does this account look like right now" —
  # consumed by BOTH the supervision show page and the guardian portal (same
  # pattern report_cards' Computation established, v1.17.0: one computation,
  # two surfaces, so they can never disagree on the figures). Charge has no
  # FK to StudentAccount (it belongs_to :student directly) — this is the one
  # place that bridges account -> student -> charges.
  class AccountStatement
    Result = Data.define(:account, :balance, :currency, :overdue_total, :pending_charges, :ledger_lines)
    LedgerLine = Data.define(:date, :concept, :amount, :kind)

    def self.call(account)
      new(account).call
    end

    def initialize(account)
      @account = account
    end

    def call
      Result.new(
        account: account,
        balance: account.balance,
        currency: account.currency,
        overdue_total: charges.where(status: "overdue").sum(:amount),
        pending_charges: charges.where(status: %w[pending overdue]).order(:due_on),
        ledger_lines: ledger_lines
      )
    end

    private

    attr_reader :account

    def charges
      Finance::Charge.where(institution_id: account.institution_id, student_id: account.student_id)
    end

    def payments
      Finance::Payment.where(institution_id: account.institution_id, student_account_id: account.id)
    end

    def ledger_lines
      charge_lines = charges.map do |charge|
        LedgerLine.new(date: charge.due_on || charge.created_at.to_date,
          concept: charge.description.presence || "Cargo #{charge.invoice_number}", amount: charge.amount, kind: :charge)
      end
      payment_lines = payments.map do |payment|
        LedgerLine.new(date: (payment.paid_at || payment.created_at).to_date,
          concept: "Pago (#{payment.method})", amount: payment.amount, kind: :payment)
      end
      (charge_lines + payment_lines).sort_by(&:date).reverse
    end
  end
end
