module IdentityAccess
  module Invitations
    # An invitee who sees wrong critical data (name, document, roster info) on
    # the completion screen can never edit it from here — only flag it. Reuses
    # audit_events as the inbox instead of inventing a new table; a future
    # "bandeja de discrepancias" view is just a filtered audit_events#index.
    class DiscrepancyReporter
      def self.call(invitation:, message:)
        new(invitation, message).call
      end

      def initialize(invitation, message)
        @invitation = invitation
        @message = message
      end

      def call
        Audit.log(
          institution: invitation.institution, action: "invitation.discrepancy_reported",
          target: invitation.user, metadata: { message: message.to_s.strip.presence }
        )
      end

      private

      attr_reader :invitation, :message
    end
  end
end
