module Finance
  class PaymentPlan < ApplicationRecord
    self.table_name = "payment_plans"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    has_many :installments, class_name: "Finance::Installment",
             foreign_key: :payment_plan_id, inverse_of: :payment_plan, dependent: :destroy
    validates :name, :total_amount, :currency, :status, presence: true
  end
end
