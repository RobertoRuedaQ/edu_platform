module IdentityAccess
  module Invitations
    # Issues (or re-issues) an invitation for a person the institution already
    # created a `users` row for. Invalidates any prior LIVE invitation for the
    # same (institution, user) first, so this doubles as the resender — a
    # separate Resender class would just be this same call.
    class Issuer
      Issued = Data.define(:invitation, :token)

      TTL = 7.days

      def self.call(user:, institution:, created_by: nil)
        new(user, institution, created_by).call
      end

      def initialize(user, institution, created_by)
        @user = user
        @institution = institution
        @created_by = created_by
      end

      def call
        token = generate_token
        invalidate_prior
        invitation = create_invitation(token)
        deliver(token)
        Audit.log(institution: institution, actor_institution_user: created_by,
          action: "invitation.sent", target: invitation)
        Issued.new(invitation: invitation, token: token)
      end

      private

      attr_reader :user, :institution, :created_by

      def generate_token
        SecureRandom.urlsafe_base64(32)
      end

      def invalidate_prior
        live_scope.update_all(status: "expired")
      end

      def create_invitation(token)
        Invitation.create!(
          user: user, institution: institution, email: user.email,
          token_digest: Digest::SHA256.hexdigest(token), status: "sent",
          expires_at: TTL.from_now, sent_at: Time.current, created_by: created_by
        )
      end

      # Plain primitives, same reasoning as OtpMailer: deliver_later runs async
      # with no tenant GUC, so it must not depend on loading the RLS-scoped
      # Invitation record. The subdomain carries the tenant for the link
      # itself — no token-encoded institution_id needed (see the migration's
      # breadcrumb comment for the problem this solves).
      def deliver(token)
        InvitationMailer.invite(email: user.email, institution_slug: institution.slug, token: token).deliver_later
      end

      def live_scope
        Invitation.where(user_id: user.id, institution_id: institution.id, status: "sent")
      end
    end
  end
end
