module ControlPlane
  # Credential check only — a correct password does NOT sign the admin in yet,
  # it only begins the mandatory email-OTP step (see EmailOtpsController).
  # Mirrors the tenant SessionsController's shape; deliberately NOT sharing
  # code with it — see ControlPlane::Authentication and F1 in the S0 prompt.
  class SessionsController < ControlPlane::BaseController
    allow_unauthenticated_access only: %i[new create]

    rate_limit to: 10, within: 3.minutes, only: :create,
      with: -> { redirect_to new_control_plane_session_path, alert: "Demasiados intentos. Intenta de nuevo más tarde." }

    layout "control_plane_auth"

    def new
    end

    def create
      admin = authenticate_credentials
      return reject_credentials if admin.nil?

      begin_mfa_for(admin)
    end

    # Requires authentication (NOT in the allow_unauthenticated_access list).
    def destroy
      ControlPlane::Audit.log(action: "sign_out", platform_admin: current_platform_admin,
        ip_address: request.remote_ip)
      terminate_control_plane_session
      redirect_to new_control_plane_session_path, notice: "Cerraste sesión."
    end

    private

    # Same generic outcome for unknown email / wrong password / suspended
    # admin — never reveal which failed (anti-enumeration).
    def authenticate_credentials
      admin = ControlPlane::PlatformAdmin.find_by(email: params[:email].to_s.downcase.strip)
      ok = admin&.authenticate(params[:password]) && admin.active?
      log_attempt(admin, ok)
      ok ? admin : nil
    end

    def log_attempt(admin, ok)
      action = ok ? "sign_in.credentials_ok" : "sign_in.credentials_failed"
      ControlPlane::Audit.log(action: action, platform_admin: (admin if ok),
        metadata: { email: params[:email].to_s }, ip_address: request.remote_ip)
    end

    def begin_mfa_for(admin)
      session[:pending_platform_admin_id] = admin.id
      ControlPlane::Otp::Issuer.call(platform_admin: admin)
      ControlPlane::Audit.log(action: "otp.issued", platform_admin: admin, ip_address: request.remote_ip)
      redirect_to new_control_plane_email_otp_path
    end

    def reject_credentials
      flash.now[:alert] = "Credenciales inválidas."
      render :new, status: :unprocessable_entity
    end
  end
end
