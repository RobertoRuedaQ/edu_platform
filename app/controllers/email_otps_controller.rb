# Second factor for login. Reachable only with a pending login in flight
# (session[:pending_user_id], set by SessionsController#create) and a resolved
# tenant. A successful code starts the real Core::Session.
class EmailOtpsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_email_otp_path, alert: "Demasiados intentos. Intenta de nuevo más tarde." }

  layout "auth"
  before_action :require_pending_login

  def new
  end

  # Re-POSTing without a code (link "reenviar") reissues; with a code, verifies.
  def create
    return resend_code if params[:code].blank?

    verify_code
  end

  private

  def require_pending_login
    redirect_to new_session_path if pending_user.nil? || Current.institution.nil?
  end

  def pending_user
    @pending_user ||= Core::User.find_by(id: session[:pending_user_id])
  end

  def verify_code
    result = IdentityAccess::Otp::Verifier.call(
      user: pending_user, institution: Current.institution,
      code: params[:code].to_s, purpose: "login"
    )
    result.success? ? complete_login : reject_code
  end

  def resend_code
    IdentityAccess::Otp::Issuer.call(user: pending_user, institution: Current.institution, purpose: "login")
    redirect_to new_email_otp_path, notice: "Te enviamos un nuevo código."
  end

  def complete_login
    session.delete(:pending_user_id)
    start_new_session_for(pending_user, institution: Current.institution)
    redirect_to after_authentication_url, notice: "Sesión iniciada."
  end

  def reject_code
    flash.now[:alert] = "Código incorrecto."
    render :new, status: :unprocessable_entity
  end
end
