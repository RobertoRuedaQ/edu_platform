module Finance
  class Charge < ApplicationRecord
    self.table_name = "charges"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    has_many :payments, class_name: "Finance::Payment",
             foreign_key: :charge_id, inverse_of: :charge, dependent: :restrict_with_exception
    validates :invoice_number, :amount, :currency, :status, presence: true
  end
end
