module IdentityAccess
  # A one-time code for email login or step-up MFA. Only the digest is stored;
  # verification/consumption logic comes in the auth phase.
  class EmailOtp < ApplicationRecord
    self.table_name = "email_otps"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :user, class_name: "Core::User"
  end
end
