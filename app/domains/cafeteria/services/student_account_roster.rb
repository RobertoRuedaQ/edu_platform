module Cafeteria
  # STUB balances, one per real (stub) GroupManagement::StudentRoster entry —
  # student_accounts is a real table but carries no seed data and no AR model
  # yet. Institution-wide only (no group scope mentioned in Apéndice A for
  # treasury): balances aren't naturally a per-group concept.
  #
  # TODO: reemplazar por Cafeteria::StudentAccount real cuando exista.
  module StudentAccountRoster
    Row = Data.define(:student_id, :student_name, :group_name, :balance, :currency)

    BALANCES = [ 24_500, 15_200, 8_900, 32_000, 5_400, 18_750, 0, 41_300, 12_100 ].freeze
    private_constant :BALANCES

    def self.all
      GroupManagement::StudentRoster.all.each_with_index.map do |student, i|
        Row.new(student_id: student.id, student_name: student.name, group_name: student.group_name,
                balance: BALANCES[i % BALANCES.size], currency: "COP")
      end
    end
  end
end
