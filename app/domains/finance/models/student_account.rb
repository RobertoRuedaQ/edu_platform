module Finance
  # Running balance per student. lock_version enables ActiveRecord optimistic
  # locking on the balance (concurrent payments won't lose updates).
  class StudentAccount < ApplicationRecord
    self.table_name = "student_accounts"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    has_many :payments, class_name: "Finance::Payment",
             foreign_key: :student_account_id, inverse_of: :student_account, dependent: :restrict_with_exception
    validates :balance, :currency, presence: true
  end
end
