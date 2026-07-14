module Finance
  class Payment < ApplicationRecord
    self.table_name = "payments"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student_account, class_name: "Finance::StudentAccount", inverse_of: :payments
    belongs_to :charge, class_name: "Finance::Charge", optional: true, inverse_of: :payments
    validates :amount, :currency, :method, :status, presence: true
  end
end
