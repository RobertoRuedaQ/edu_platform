# Native Rails 8 session auth (no Devise). Mirrors the shape produced by
# `rails generate authentication`, adapted to this app's Core::Session /
# Core::User and a signed, httponly cookie.
#
# NOTE on the two "sessions": `session[...]` below is the RAILS cookie session
# (a short-lived key/value store), which is DISTINCT from `Current.session`
# (the persisted Core::Session record). They share a word, not a concept.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    # Declarative opt-out for pre-login endpoints (login, OTP).
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    Current.session.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    return if cookies.signed[:session_id].blank?
    Core::Session.find_by(id: cookies.signed[:session_id])
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url # Rails cookie session
    redirect_to new_session_path
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  def start_new_session_for(user, institution: nil)
    user.sessions.create!(current_institution: institution,
      user_agent: request.user_agent, ip_address: request.remote_ip).tap do |record|
      Current.session = record
      set_session_cookie(record)
    end
  end

  def set_session_cookie(record)
    cookies.signed.permanent[:session_id] = { value: record.id, httponly: true, same_site: :lax }
  end

  def terminate_session
    Current.session&.destroy!
    cookies.delete(:session_id)
    Current.session = nil
  end
end
