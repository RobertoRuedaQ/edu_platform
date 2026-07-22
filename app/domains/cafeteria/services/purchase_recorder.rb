module Cafeteria
  # Records a cafeteria sale — same discipline as Finance::ChargeCreator/
  # PaymentRecorder and Extracurriculars::EnrollmentCreator (account.lock!,
  # transactional, idempotent). A purchase is a Finance::Charge against the
  # ONE shared student_accounts wallet (never a cafeteria-owned ledger — see
  # the migration comment for why), created in the SAME transaction as the
  # Purchase/PurchaseLine rows: if the charge fails, the sale never persists.
  #
  # Idempotent on Purchase's OWN idempotency_key (not just ChargeCreator's) —
  # without locking the account first, two concurrent submits of the same key
  # would both pass a pre-lock existence check and race to the unique index,
  # surfacing a raw ActiveRecord::RecordNotUnique instead of the graceful
  # "return the existing sale" this checkout flow needs.
  #
  # M1 metering (OPEN_PROCESS.md item #5, molde S3b v1.30.0): emits one
  # "compras" usage event per real Purchase.
  class PurchaseRecorder
    def self.call(institution:, student:, menu_items:, recorded_by:, idempotency_key: nil)
      new(institution: institution, student: student, menu_items: menu_items,
        recorded_by: recorded_by, idempotency_key: idempotency_key).call
    end

    def initialize(institution:, student:, menu_items:, recorded_by:, idempotency_key:)
      @institution = institution
      @student = student
      @menu_items = menu_items
      @recorded_by = recorded_by
      @idempotency_key = idempotency_key
    end

    def call
      account = find_or_create_account

      Finance::StudentAccount.transaction do
        account.lock!

        existing = existing_purchase
        next existing if existing

        charge = Finance::ChargeCreator.call(
          institution: institution, account: account, amount: total_amount,
          description: "Compra de cafetería: #{menu_items.map(&:name).join(', ')}",
          idempotency_key: idempotency_key
        )

        purchase = Cafeteria::Purchase.create!(
          institution: institution, student: student, recorded_by: recorded_by, charge: charge,
          purchased_at: Time.current, total_price_cents: total_cents, idempotency_key: idempotency_key
        )
        menu_items.each do |item|
          Cafeteria::PurchaseLine.create!(institution: institution, purchase: purchase, menu_item: item,
            item_name: item.name, unit_price_cents: item.price_cents)
        end
        emit_usage(purchase)
        purchase
      end
    end

    private

    attr_reader :institution, :student, :menu_items, :recorded_by, :idempotency_key

    # student_accounts is NEVER lazily created elsewhere in this app either
    # (finance's own controllers 404 on a missing account) — find-or-create
    # here is safe only because of student_accounts' unique (institution_id,
    # student_id) index, same reasoning as EnrollmentCreator#charge_for_paid_activity.
    def find_or_create_account
      Finance::StudentAccount.find_or_create_by!(institution_id: institution.id, student_id: student.id) do |a|
        a.balance = 0
        a.currency = "COP"
      end
    end

    def existing_purchase
      return nil if idempotency_key.blank?

      Cafeteria::Purchase.find_by(institution_id: institution.id, idempotency_key: idempotency_key)
    end

    def total_cents
      menu_items.sum(&:price_cents)
    end

    def total_amount
      BigDecimal(total_cents) / 100
    end

    # M1 (OPEN_PROCESS.md item #5): one "compras" unit per NEW real Purchase —
    # only reached past the `next existing if existing` guard above, so a
    # resubmitted idempotency_key never re-emits.
    def emit_usage(purchase)
      ControlPlane::Usage::Ingest.emit(institution: institution, addon_key: "cafeteria",
        unit: "compras", occurred_at: purchase.purchased_at, idempotency_key: "cafeteria_purchase:#{purchase.id}")
    end
  end
end
