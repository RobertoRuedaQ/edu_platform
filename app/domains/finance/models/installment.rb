module Finance
  class Installment < ApplicationRecord
    self.table_name = "installments"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :payment_plan, class_name: "Finance::PaymentPlan", inverse_of: :installments
    validates :sequence, :amount, :due_on, :status, presence: true
  end
end
