# Login is per-subdomain ("login único por subdominio"): the tenant must be
# resolved (via TenantScoped) before we authenticate. Password success does NOT
# start a session — it only begins the mandatory email-OTP step.
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "Demasiados intentos. Intenta de nuevo más tarde." }

  layout "auth"

  def new
  end

  def create
    return render_no_tenant if Current.institution.nil?

    user = authenticate_credentials
    return reject_credentials if user.nil?

    begin_mfa_for(user)
  end

  # Requires authentication (NOT in the allow_unauthenticated_access list).
  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Cerraste sesión."
  end

  private

  # Same generic outcome for unknown email / wrong password / non-member — never
  # reveal which failed (anti-enumeration).
  def authenticate_credentials
    user = Core::User.find_by(email: params[:email].to_s.downcase.strip)
    return unless user&.authenticate(params[:password])
    return unless user.memberships.exists?(institution_id: Current.institution_id)

    user
  end

  def begin_mfa_for(user)
    session[:pending_user_id] = user.id # Rails cookie session, short-lived
    IdentityAccess::Otp::Issuer.call(user: user, institution: Current.institution, purpose: "login")
    redirect_to new_email_otp_path
  end

  def reject_credentials
    flash.now[:alert] = "Credenciales inválidas."
    render :new, status: :unprocessable_entity
  end

  def render_no_tenant
    render :no_tenant, status: :unprocessable_entity
  end
end
