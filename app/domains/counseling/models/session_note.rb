module Counseling
  # Sensitive note within a case. `confidential` defaults true. Column-level
  # encryption is a future option (see README); not enabled in this phase.
  class SessionNote < ApplicationRecord
    self.table_name = "session_notes"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :counseling_case, class_name: "Counseling::Case", inverse_of: :session_notes
    belongs_to :author, class_name: "Core::InstitutionUser"
    validates :occurred_at, :body, presence: true
  end
end
