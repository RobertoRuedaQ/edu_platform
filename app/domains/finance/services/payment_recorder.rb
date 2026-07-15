module Finance
  # Records an offline payment (cash/transfer/card slip/other) against a
  # StudentAccount — NEVER a payment gateway charge (no rail this slice, see
  # HISTORIA.md v1.18.0). Transactional: the Payment row and the balance
  # update happen atomically, under a row lock on the account
  # (`account.lock!` — pessimistic, chosen over relying solely on the
  # existing `lock_version` optimistic column so a concurrent second
  # recorder BLOCKS and waits instead of racing to a StaleObjectError the
  # caller would have to retry). Idempotent: the controller generates an
  # `idempotency_key` once per form render (hidden field) so a double-submit
  # of the SAME key returns the already-recorded payment instead of
  # recording a second one — the natural `idempotency_key` unique index on
  # `payments` is the backstop if two requests somehow race past the
  # pre-check.
  #
  # Money is `decimal` here (not `*_cents bigint`, see HISTORIA.md v1.18.0's
  # recon finding) — BigDecimal arithmetic throughout, NEVER cast to Float.
  class PaymentRecorder
    def self.call(institution:, account:, amount:, method:, idempotency_key: nil, charge: nil, received_at: Time.current)
      new(institution: institution, account: account, amount: amount, method: method,
        idempotency_key: idempotency_key, charge: charge, received_at: received_at).call
    end

    def initialize(institution:, account:, amount:, method:, idempotency_key:, charge:, received_at:)
      @institution = institution
      @account = account
      @amount = amount
      @method = method
      @idempotency_key = idempotency_key.presence
      @charge = charge
      @received_at = received_at
    end

    def call
      existing = find_existing
      return existing if existing

      Finance::StudentAccount.transaction do
        account.lock!
        existing = find_existing
        next existing if existing

        payment = Finance::Payment.create!(institution: institution, student_account: account, charge: charge,
          amount: amount, currency: account.currency, method: method, status: "completed",
          paid_at: received_at, idempotency_key: idempotency_key)
        account.update!(balance: account.balance - amount)
        mark_charge_paid_if_settled!
        payment
      end
    end

    private

    attr_reader :institution, :account, :amount, :method, :idempotency_key, :charge, :received_at

    def find_existing
      return nil if idempotency_key.nil?

      Finance::Payment.find_by(institution_id: institution.id, idempotency_key: idempotency_key)
    end

    def mark_charge_paid_if_settled!
      return if charge.nil?

      paid_so_far = Finance::Payment.where(institution_id: institution.id, charge_id: charge.id,
        status: "completed").sum(:amount)
      charge.update!(status: "paid") if paid_so_far >= charge.amount && charge.status != "paid"
    end
  end
end
