module Portals
  # The student's own cafeteria balance + purchase history (guidelines/
  # CLOSURE_PLAN.md Fase D — cafeteria resto). Reads the ONE shared
  # Finance::StudentAccount wallet (never a cafeteria-owned ledger) and this
  # student's own Cafeteria::Purchase rows — real transactions now, not the
  # three hardcoded rows the old stub carried (there is no top-up/"Recarga"
  # flow anywhere in this app, so every real transaction here is money out).
  class StudentCafeteriaAccount
    Transaction = Data.define(:occurred_at, :description, :amount)

    def self.for(student)
      return new(balance: 0, currency: "COP", student: nil) if student.nil?

      account = Finance::StudentAccount.find_by(institution_id: Current.institution_id, student_id: student.id)
      new(balance: account&.balance || 0, currency: account&.currency || "COP", student: student)
    end

    def initialize(balance:, currency:, student:)
      @balance = balance
      @currency = currency
      @student = student
    end

    attr_reader :balance, :currency

    def transactions
      return [] if student.nil?

      Cafeteria::Purchase
        .where(institution_id: Current.institution_id, student_id: student.id)
        .order(purchased_at: :desc)
        .limit(20)
        .map { |purchase| Transaction.new(occurred_at: purchase.purchased_at, description: "Compra: #{purchase.item_names}",
          amount: -purchase.total_price_amount) }
    end

    private

    attr_reader :student
  end
end
