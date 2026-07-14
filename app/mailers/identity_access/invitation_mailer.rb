module IdentityAccess
  class InvitationMailer < ApplicationMailer
    # Plain primitives (not the Invitation record): same reasoning as
    # OtpMailer — runs async with no tenant GUC. The URL's host carries the
    # institution's subdomain, so opening the link resolves the tenant the
    # same way login does (Tenant::Resolver), before the token is ever looked
    # up — that's what lets the RLS-scoped `invitations` row be found without
    # any BYPASSRLS or token-encoded institution_id.
    def invite(email:, institution_slug:, token:)
      base = Rails.application.config.action_mailer.default_url_options
      @url = edit_invitation_url(token, host: "#{institution_slug}.#{base[:host]}", port: base[:port])
      mail(to: email, subject: "Completa tu cuenta")
    end
  end
end
