module ControlPlane
  # Second factor for control-plane login. Reachable only with a pending login
  # in flight (session[:pending_platform_admin_id], set by SessionsController
  # #create). A successful code starts the real ControlPlane::Session.
  class EmailOtpsController < ControlPlane::BaseController
    allow_unauthenticated_access only: %i[new create]

    rate_limit to: 10, within: 3.minutes, only: :create,
      with: -> { redirect_to new_control_plane_email_otp_path, alert: "Demasiados intentos. Intenta de nuevo más tarde." }

    layout "control_plane_auth"
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
      redirect_to new_control_plane_session_path if pending_admin.nil?
    end

    def pending_admin
      @pending_admin ||= ControlPlane::PlatformAdmin.find_by(id: session[:pending_platform_admin_id])
    end

    def verify_code
      result = ControlPlane::Otp::Verifier.call(platform_admin: pending_admin, code: params[:code].to_s)
      result.success? ? complete_login : reject_code(result)
    end

    def resend_code
      ControlPlane::Otp::Issuer.call(platform_admin: pending_admin)
      ControlPlane::Audit.log(action: "otp.issued", platform_admin: pending_admin, ip_address: request.remote_ip)
      redirect_to new_control_plane_email_otp_path, notice: "Te enviamos un nuevo código."
    end

    def complete_login
      admin = pending_admin
      session.delete(:pending_platform_admin_id)
      start_new_control_plane_session_for(admin)
      ControlPlane::Audit.log(action: "otp.verified", platform_admin: admin, ip_address: request.remote_ip)
      redirect_to control_plane_root_path, notice: "Sesión iniciada."
    end

    def reject_code(result)
      action = result.error == "locked" ? "otp.locked" : "otp.failed"
      ControlPlane::Audit.log(action: action, platform_admin: pending_admin,
        metadata: { error: result.error }, ip_address: request.remote_ip)
      flash.now[:alert] = "Código incorrecto."
      render :new, status: :unprocessable_entity
    end
  end
end
