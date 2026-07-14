require "test_helper"

# Full first-authentication flow: per-subdomain password login + mandatory
# email OTP. Builds its own user/institution/membership (no fixtures for these).
class AuthenticationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @institution = Core::Institution.create!(name: "Colegio Test", slug: "colegio-test", code: "CT-1", kind: "school")
    @user = Core::User.create!(email: "profe@colegio.test", name: "Ana Profe", password: PASSWORD)
    within_tenant(@institution) { @institution.memberships.create!(user: @user) }
    host! "colegio-test.example.com"
  end

  test "an unauthenticated request to a protected page redirects to login" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "full login: correct password then correct OTP lands on an authenticated page" do
    perform_enqueued_jobs do
      post session_path, params: { email: @user.email, password: PASSWORD }
    end
    assert_redirected_to new_email_otp_path

    post email_otp_path, params: { code: last_otp_code }
    assert_response :redirect
    follow_redirect!

    assert_response :success
    assert_equal "/", path # dashboard, not a bounce back to /session/new
  end

  test "wrong password is rejected generically and never issues an OTP" do
    perform_enqueued_jobs do
      post session_path, params: { email: @user.email, password: "wrong" }
    end
    assert_response :unprocessable_entity
    assert_empty ActionMailer::Base.deliveries
  end

  test "an unknown email is rejected the same way as a wrong password" do
    perform_enqueued_jobs do
      post session_path, params: { email: "nobody@nowhere.test", password: PASSWORD }
    end
    assert_response :unprocessable_entity
    assert_empty ActionMailer::Base.deliveries
  end

  test "login without a resolved tenant renders the no-tenant state" do
    host! "www.example.com" # reserved subdomain -> no institution
    post session_path, params: { email: @user.email, password: PASSWORD }
    assert_response :unprocessable_entity
    assert_select "h1", text: /No pudimos identificar la institución/
  end

  test "an incorrect OTP code is rejected" do
    start_login
    post email_otp_path, params: { code: wrong_code }
    assert_response :unprocessable_entity
  end

  test "OTP locks out after 5 wrong attempts, rejecting even the correct code" do
    start_login
    correct = last_otp_code

    5.times do
      post email_otp_path, params: { code: wrong_code }
      assert_response :unprocessable_entity
    end

    # 6th attempt with the RIGHT code is still rejected: the code is locked.
    post email_otp_path, params: { code: correct }
    assert_response :unprocessable_entity

    # And no session was established.
    get root_path
    assert_redirected_to new_session_path
  end

  private

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def start_login
    perform_enqueued_jobs do
      post session_path, params: { email: @user.email, password: PASSWORD }
    end
  end

  # A 6-digit code guaranteed different from the real one.
  def wrong_code
    last_otp_code == "000000" ? "111111" : "000000"
  end
end
