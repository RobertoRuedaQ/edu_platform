module Portals
  # STUB cafeteria account for the student's own portal. Same "Ana Martínez"
  # identity as Portals::StudentDashboard (whose shortcut stat already shows
  # this exact balance) — kept as its own small presenter rather than bolted
  # onto StudentDashboard, since that class owns the dashboard tiles, not
  # cafeteria specifics.
  #
  # TODO: reemplazar por Cafeteria::StudentAccount real (students.user_id).
  class StudentCafeteriaAccount
    Transaction = Data.define(:occurred_at, :description, :amount)

    def self.stub
      new(balance: 24_500, currency: "COP")
    end

    def initialize(balance:, currency:)
      @balance = balance
      @currency = currency
    end

    attr_reader :balance, :currency

    def transactions
      [
        Transaction.new(occurred_at: Date.new(2026, 7, 3), description: "Almuerzo", amount: -9_500),
        Transaction.new(occurred_at: Date.new(2026, 7, 2), description: "Snack", amount: -3_800),
        Transaction.new(occurred_at: Date.new(2026, 7, 1), description: "Recarga", amount: 40_000)
      ]
    end
  end
end
