module ControlPlane
  # Mirrors the tenant's top-level Authentication concern in structure, but is
  # entirely independent: separate cookie name, separate Current, separate
  # Session model. A Core::User session can never resume here, and this
  # session can never resume in the tenant app — see
  # test/integration/control_plane/authentication_test.rb for the isolation
  # test that pins this down.
  module Authentication
    extend ActiveSupport::Concern

    COOKIE_NAME = :control_plane_session_id

    included do
      before_action :require_platform_admin
      helper_method :platform_admin_signed_in?
    end

    class_methods do
      def allow_unauthenticated_access(**options)
        skip_before_action :require_platform_admin, **options
      end
    end

    private

    def platform_admin_signed_in?
      ControlPlane::Current.session.present?
    end

    def require_platform_admin
      resume_control_plane_session || request_platform_admin_authentication
    end

    def resume_control_plane_session
      ControlPlane::Current.session ||= find_control_plane_session_by_cookie
    end

    def find_control_plane_session_by_cookie
      return if cookies.signed[COOKIE_NAME].blank?
      ControlPlane::Session.find_by(id: cookies.signed[COOKIE_NAME])
    end

    def request_platform_admin_authentication
      redirect_to new_control_plane_session_path
    end

    def start_new_control_plane_session_for(platform_admin)
      platform_admin.sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent).tap do |record|
        ControlPlane::Current.session = record
        set_control_plane_session_cookie(record)
        platform_admin.update!(last_sign_in_at: Time.current)
      end
    end

    def set_control_plane_session_cookie(record)
      cookies.signed.permanent[COOKIE_NAME] = { value: record.id, httponly: true, same_site: :lax }
    end

    def terminate_control_plane_session
      ControlPlane::Current.session&.destroy!
      cookies.delete(COOKIE_NAME)
      ControlPlane::Current.session = nil
    end
  end
end
