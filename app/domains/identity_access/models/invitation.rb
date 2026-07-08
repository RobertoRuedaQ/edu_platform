module IdentityAccess
  # A pending onboarding invitation. Only the token DIGEST is persisted, never
  # the raw token — see Invitations::Issuer/Completer for generation/verification.
  class Invitation < ApplicationRecord
    self.table_name = "invitations"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :user, class_name: "Core::User"
    belongs_to :created_by, class_name: "Core::InstitutionUser", optional: true

    def usable? = status == "sent" && expires_at.future?
  end
end
