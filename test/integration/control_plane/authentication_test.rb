require "test_helper"

# Full control-plane login flow: password + mandatory email OTP, entirely
# separate from the tenant's own SessionsController/EmailOtpsController stack.
class ControlPlane::AuthenticationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "root@platform.test", name: "Root Admin",
      password: PASSWORD, status: "active")
  end

  test "an unauthenticated request to a protected control-plane page redirects to control-plane login" do
    get control_plane_root_path
    assert_redirected_to new_control_plane_session_path
  end

  test "full login: correct password then correct OTP lands on the dashboard, auditing every step" do
    perform_enqueued_jobs do
      post control_plane_session_path, params: { email: @admin.email, password: PASSWORD }
    end
    assert_redirected_to new_control_plane_email_otp_path

    post control_plane_email_otp_path, params: { code: last_otp_code }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    actions = ControlPlane::AuditEvent.where(platform_admin: @admin).pluck(:action)
    assert_includes actions, "sign_in.credentials_ok"
    assert_includes actions, "otp.issued"
    assert_includes actions, "otp.verified"
  end

  test "wrong password is rejected generically, audited, and never issues an OTP" do
    perform_enqueued_jobs do
      post control_plane_session_path, params: { email: @admin.email, password: "wrong" }
    end
    assert_response :unprocessable_entity
    assert_empty ActionMailer::Base.deliveries
    assert ControlPlane::AuditEvent.exists?(action: "sign_in.credentials_failed")
  end

  test "an unknown email is rejected the same way as a wrong password (anti-enumeration)" do
    perform_enqueued_jobs do
      post control_plane_session_path, params: { email: "nobody@nowhere.test", password: PASSWORD }
    end
    assert_response :unprocessable_entity
    assert_empty ActionMailer::Base.deliveries
  end

  test "a suspended platform_admin cannot sign in even with the correct password" do
    @admin.suspend!
    perform_enqueued_jobs do
      post control_plane_session_path, params: { email: @admin.email, password: PASSWORD }
    end
    assert_response :unprocessable_entity
    assert_empty ActionMailer::Base.deliveries
  end

  test "an incorrect OTP code is rejected and audited" do
    start_login
    post control_plane_email_otp_path, params: { code: wrong_code }
    assert_response :unprocessable_entity
    assert ControlPlane::AuditEvent.exists?(action: "otp.failed")
  end

  test "OTP locks out after 5 wrong attempts, rejecting even the correct code" do
    start_login
    correct = last_otp_code

    5.times do
      post control_plane_email_otp_path, params: { code: wrong_code }
      assert_response :unprocessable_entity
    end

    post control_plane_email_otp_path, params: { code: correct }
    assert_response :unprocessable_entity
    assert ControlPlane::AuditEvent.exists?(action: "otp.locked")

    get control_plane_root_path
    assert_redirected_to new_control_plane_session_path
  end

  test "sign out audits and actually terminates the session" do
    sign_in_as_platform_admin(@admin, password: PASSWORD)
    delete control_plane_session_path
    assert ControlPlane::AuditEvent.exists?(action: "sign_out", platform_admin_id: @admin.id)

    get control_plane_root_path
    assert_redirected_to new_control_plane_session_path
  end

  # --- Plane isolation (the test corona) ------------------------------------

  test "a tenant Core::User session cannot authenticate against the control plane" do
    tenant_password = "tenant-password-123456"
    institution = Core::Institution.create!(name: "Colegio Aislado", slug: "colegio-aislado",
      code: "CA-1", kind: "school")
    user = Core::User.create!(email: "profe@colegio-aislado.test", name: "Profe", password: tenant_password)
    within_tenant(institution) { institution.memberships.create!(user: user) }
    sign_in_as(user, institution: institution, password: tenant_password)

    # The tenant session cookie (:session_id) is set, but the control plane
    # reads a DIFFERENT cookie (:control_plane_session_id) and a different
    # Session model entirely — so it must still demand its own login.
    get control_plane_root_path
    assert_redirected_to new_control_plane_session_path
  end

  test "a platform_admin session does not grant access to a tenant-authenticated route" do
    sign_in_as_platform_admin(@admin, password: PASSWORD)

    institution = Core::Institution.create!(name: "Colegio Otro", slug: "colegio-otro",
      code: "CO-1", kind: "school")
    host! "colegio-otro.example.com"

    get root_path
    assert_redirected_to new_session_path
  end

  test "control-plane and tenant session cookies are independent" do
    tenant_password = "tenant-password-123456"
    institution = Core::Institution.create!(name: "Colegio Cookies", slug: "colegio-cookies",
      code: "CC-1", kind: "school")
    user = Core::User.create!(email: "profe@colegio-cookies.test", name: "Profe", password: tenant_password)
    within_tenant(institution) { institution.memberships.create!(user: user) }
    sign_in_as(user, institution: institution, password: tenant_password)
    assert cookies[:session_id].present?
    assert_nil cookies[:control_plane_session_id]

    sign_in_as_platform_admin(@admin, password: PASSWORD)
    assert cookies[:control_plane_session_id].present?
  end

  private

  def start_login
    perform_enqueued_jobs do
      post control_plane_session_path, params: { email: @admin.email, password: PASSWORD }
    end
  end

  def wrong_code
    correct = last_otp_code
    digits = ("000000".."999999").to_a
    digits.delete(correct)
    digits.sample
  end

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end
end
