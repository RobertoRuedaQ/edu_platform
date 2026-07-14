module IdentityAccess
  module Invitations
    # Sets the invited user's password and marks the invitation completed.
    # Never touches name/email/document — those are read-only on the
    # completion screen by design (the institution, not the invitee, is the
    # identity guarantor). Caller is responsible for starting the real session
    # afterward (mirrors EmailOtpsController calling start_new_session_for
    # itself instead of the verifier doing it).
    class Completer
      MIN_PASSWORD_LENGTH = 12

      def self.call(invitation:, password:, password_confirmation:)
        new(invitation, password, password_confirmation).call
      end

      def initialize(invitation, password, password_confirmation)
        @invitation = invitation
        @password = password
        @password_confirmation = password_confirmation
      end

      def call
        return Result.failure("weak_password") if password.to_s.length < MIN_PASSWORD_LENGTH

        user.password = password
        user.password_confirmation = password_confirmation
        return Result.failure("invalid_password") unless user.save

        invitation.update!(status: "completed", completed_at: Time.current)
        Audit.log(institution: invitation.institution, action: "invitation.completed", target: user)
        Result.success(user)
      end

      private

      attr_reader :invitation, :password, :password_confirmation

      def user = invitation.user
    end
  end
end
