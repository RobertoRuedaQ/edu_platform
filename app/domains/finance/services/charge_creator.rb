module Finance
  # Creates a Charge against a student and raises the account's balance —
  # transactional and lock-guarded, same discipline as PaymentRecorder.
  # `invoice_number` is the human-facing business id — generated here, never
  # typed by the treasury actor, so a double-submit of the same form (same
  # `idempotency_key`, carried in a hidden field from #new) returns the
  # already-created charge instead of minting a second invoice number.
  class ChargeCreator
    def self.call(institution:, account:, amount:, description: nil, due_on: nil, idempotency_key: nil)
      new(institution: institution, account: account, amount: amount, description: description,
        due_on: due_on, idempotency_key: idempotency_key).call
    end

    def initialize(institution:, account:, amount:, description:, due_on:, idempotency_key:)
      @institution = institution
      @account = account
      @amount = amount
      @description = description
      @due_on = due_on
      @idempotency_key = idempotency_key.presence
    end

    def call
      existing = find_existing
      return existing if existing

      Finance::StudentAccount.transaction do
        account.lock!
        existing = find_existing
        next existing if existing

        charge = Finance::Charge.create!(institution: institution, student: account.student,
          invoice_number: generate_invoice_number, description: description, amount: amount,
          currency: account.currency, due_on: due_on, status: "pending", idempotency_key: idempotency_key)
        account.update!(balance: account.balance + amount)
        charge
      end
    end

    private

    attr_reader :institution, :account, :amount, :description, :due_on, :idempotency_key

    def find_existing
      return nil if idempotency_key.nil?

      Finance::Charge.find_by(institution_id: institution.id, idempotency_key: idempotency_key)
    end

    def generate_invoice_number
      "INV-#{Time.current.strftime('%Y%m')}-#{SecureRandom.hex(4).upcase}"
    end
  end
end
