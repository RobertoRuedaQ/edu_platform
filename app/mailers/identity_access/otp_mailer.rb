module IdentityAccess
  class OtpMailer < ApplicationMailer
    # Plain primitives (not the EmailOtp record): the record is RLS-scoped and
    # this runs async with no tenant GUC, and it only holds a digest anyway.
    def code(email:, code:)
      @code = code
      mail(to: email, subject: "Tu código de acceso")
    end
  end
end
