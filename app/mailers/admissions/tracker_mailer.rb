module Admissions
  class TrackerMailer < ApplicationMailer
    # Primitivos planos (nunca el AR record) — molde exacto
    # IdentityAccess::InvitationMailer#invite: corre async sin GUC de
    # tenant, el host de la URL carga el subdominio de la institución, así
    # que abrir el link resuelve el tenant igual que el login (Tenant::
    # Resolver) antes de que el token se busque siquiera.
    def notify(email:, institution_slug:, token:)
      base = Rails.application.config.action_mailer.default_url_options
      @url = applicant_tracker_url(token, host: "#{institution_slug}.#{base[:host]}", port: base[:port])
      mail(to: email, subject: "Consulta el estado de tu solicitud de admisión")
    end
  end
end
