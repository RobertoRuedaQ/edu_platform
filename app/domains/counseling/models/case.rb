module Counseling
  # A counseling case for a student. Sensitive: RLS is the baseline (tenant
  # isolation); counseling.read (#4 barrido, v1.14.0) is the app-layer gate
  # the README long documented as "planned, not yet implemented" — see
  # CaseScope.
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

    # Scope-covering descriptor: a case has no department/group column of its
    # own — it's derived from the student it's about. The stub CaseRoster
    # this replaces used the SAME dimension (group_id), just hardcoded.
    delegate :group_id, to: :student, allow_nil: true

    def student_name
      "#{student.first_name} #{student.last_name}"
    end
  end
end
