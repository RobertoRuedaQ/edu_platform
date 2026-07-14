module ControlPlane
  # No new/create here on purpose — S0's only alta is the bootstrap CLI task
  # (lib/tasks/control_plane.rake). This controller only manages the lifecycle
  # of admins that already exist.
  class PlatformAdminsController < ControlPlane::BaseController
    before_action :set_platform_admin, only: %i[show suspend reactivate]

    def index
      @platform_admins = ControlPlane::PlatformAdmin.order(:email)
    end

    def show
    end

    def suspend
      if @platform_admin == current_platform_admin
        return redirect_to control_plane_platform_admins_path, alert: "No puedes suspenderte a ti mismo."
      end

      if other_active_admins?
        @platform_admin.suspend!
        ControlPlane::Audit.log(action: "platform_admin.suspended", platform_admin: current_platform_admin,
          target: @platform_admin, ip_address: request.remote_ip)
        redirect_to control_plane_platform_admins_path, notice: "Administrador suspendido."
      else
        redirect_to control_plane_platform_admins_path,
          alert: "No puede quedar la plataforma sin administradores activos."
      end
    end

    def reactivate
      @platform_admin.reactivate!
      ControlPlane::Audit.log(action: "platform_admin.reactivated", platform_admin: current_platform_admin,
        target: @platform_admin, ip_address: request.remote_ip)
      redirect_to control_plane_platform_admins_path, notice: "Administrador reactivado."
    end

    private

    def set_platform_admin
      @platform_admin = ControlPlane::PlatformAdmin.find(params[:id])
    end

    def other_active_admins?
      ControlPlane::PlatformAdmin.active.where.not(id: @platform_admin.id).exists?
    end
  end
end
