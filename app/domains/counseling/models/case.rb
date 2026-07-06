module Counseling
  # A counseling case for a student. Sensitive: access is tenant-scoped now and
  # will be further restricted by the counseling.read permission in the auth
  # iteration (see README).
  class Case < ApplicationRecord
    self.table_name = "counseling_cases"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :opened_by, class_name: "Core::InstitutionUser"
    has_many :session_notes, class_name: "Counseling::SessionNote",
             foreign_key: :counseling_case_id, inverse_of: :counseling_case, dependent: :destroy
    has_many :referrals, class_name: "Counseling::Referral",
             foreign_key: :counseling_case_id, inverse_of: :counseling_case, dependent: :destroy
    validates :category, :status, :opened_at, presence: true
  end
end
