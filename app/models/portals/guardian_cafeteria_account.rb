module Portals
  # Per-child cafeteria balance for the guardian's portal (guidelines/
  # CLOSURE_PLAN.md Fase D — cafeteria resto). Reads the ONE shared
  # Finance::StudentAccount wallet (never a cafeteria-owned ledger — see
  # db/migrate/20260722060000's comment) through the SAME resolved children
  # list GuardianDashboard's shortcuts already use, so the two pages can
  # never disagree.
  module GuardianCafeteriaAccount
    Account = Data.define(:child_id, :child_name, :balance, :currency)

    def self.for_children(user)
      Core::Access::GuardianScope.for(user).map do |child|
        account = Finance::StudentAccount.find_by(institution_id: Current.institution_id, student_id: child.id)
        Account.new(
          child_id: child.id, child_name: "#{child.first_name} #{child.last_name}",
          balance: account&.balance || 0, currency: account&.currency || "COP"
        )
      end
    end
  end
end
