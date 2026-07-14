module IdentityAccess
  module Invitations
    # Marks the live invitation for (institution, email) as bounced. Not
    # wired to a live delivery webhook yet — no provider bounce receiver
    # exists in this app — but the unit is real and testable so a future
    # ActionMailer delivery-status webhook has a single call to make.
    # # TODO: wire from a real provider webhook controller once one exists.
    class BounceHandler
      def self.call(institution:, email:)
        new(institution, email).call
      end

      def initialize(institution, email)
        @institution = institution
        @email = email
      end

      def call
        invitation = live_scope.first
        return unless invitation

        invitation.update!(status: "bounced")
        Audit.log(institution: institution, action: "invitation.bounced", target: invitation)
        invitation
      end

      private

      attr_reader :institution, :email

      def live_scope
        Invitation.where(institution_id: institution.id, email: email, status: "sent")
      end
    end
  end
end
