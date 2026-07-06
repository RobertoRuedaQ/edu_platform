module Counseling
  class Referral < ApplicationRecord
    self.table_name = "referrals"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :counseling_case, class_name: "Counseling::Case", inverse_of: :referrals
    validates :referred_to, :status, presence: true
  end
end
