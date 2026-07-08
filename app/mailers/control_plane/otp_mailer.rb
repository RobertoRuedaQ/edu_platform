module ControlPlane
  class OtpMailer < ApplicationMailer
    # Plain primitives (not the EmailOtp record): the record only holds a
    # digest anyway, and this runs async via deliver_later on Solid Queue.
    # Unlike a tenant mailer job, there is no GUC to restore here even in
    # principle — the control plane has no tenant context at all.
    def code(email:, code:)
      @code = code
      mail(to: email, subject: "Tu código de acceso al plano de control")
    end
  end
end
