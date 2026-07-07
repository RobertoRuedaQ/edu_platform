module Portals
  # STUB cafeteria accounts for the guardian's portal — one per child, same
  # balances GuardianDashboard's shortcuts already show ($24.500/$10.200), so
  # the two pages agree with each other.
  #
  # TODO: reemplazar por Cafeteria::StudentAccount real vía guardian_students.
  module GuardianCafeteriaAccount
    Account = Data.define(:child_id, :child_name, :balance, :currency)

    def self.for_children
      [
        Account.new(child_id: "stub-child-1", child_name: "Ana Martínez", balance: 24_500, currency: "COP"),
        Account.new(child_id: "stub-child-2", child_name: "Luis Martínez", balance: 10_200, currency: "COP")
      ]
    end
  end
end
