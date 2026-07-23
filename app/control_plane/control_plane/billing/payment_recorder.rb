module ControlPlane
  module Billing
    # Records a MANUAL payment against an invoice — molde Finance::PaymentRecorder,
    # minus the pessimistic `account.lock!`: there is no mutable running balance
    # to protect here (paid_cents/balance_due_cents on Invoice are a computed
    # `sum`, never a column two requests could race to overwrite), so a plain
    # idempotency check is enough. Always triggered by an interactive
    # platform_admin — never the unattended path PeriodCut uses.
    class PaymentRecorder
      def self.call(invoice:, amount_cents:, method:, recorded_by:, paid_on: Date.current, notes: nil,
                    idempotency_key: nil)
        new(invoice: invoice, amount_cents: amount_cents, method: method, recorded_by: recorded_by,
          paid_on: paid_on, notes: notes, idempotency_key: idempotency_key).call
      end

      def initialize(invoice:, amount_cents:, method:, recorded_by:, paid_on:, notes:, idempotency_key:)
        @invoice = invoice
        @amount_cents = amount_cents
        @method = method
        @recorded_by = recorded_by
        @paid_on = paid_on
        @notes = notes
        @idempotency_key = idempotency_key.presence
      end

      def call
        existing = find_existing
        return existing if existing

        payment = ControlPlane::Payment.create!(
          institution_id: invoice.institution_id, invoice: invoice, amount_cents: amount_cents, method: method,
          paid_on: paid_on, notes: notes, recorded_by: recorded_by, idempotency_key: idempotency_key
        )

        ControlPlane::Audit.log(action: "payment.recorded", platform_admin: recorded_by, target: payment,
          metadata: { invoice_id: invoice.id, amount_cents: amount_cents, method: method })

        payment
      end

      private

      attr_reader :invoice, :amount_cents, :method, :recorded_by, :paid_on, :notes, :idempotency_key

      def find_existing
        return nil if idempotency_key.nil?

        ControlPlane::Payment.find_by(institution_id: invoice.institution_id, idempotency_key: idempotency_key)
      end
    end
  end
end
