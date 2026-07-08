ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Drives the REAL per-subdomain login + mandatory OTP flow and leaves the
  # signed session cookie set, so subsequent requests are authenticated.
  # `user` must already have a membership in `institution`, and `password` must
  # match the user's set password. Recommended entry point for any integration
  # test that now needs an authenticated actor after auth was wired into
  # ApplicationController.
  def sign_in_as(user, institution:, password:)
    host! "#{institution.slug}.example.com"
    perform_enqueued_jobs do
      post session_path, params: { email: user.email, password: password }
    end
    post email_otp_path, params: { code: last_otp_code }
    follow_redirect!
  end

  # The plaintext OTP off the last delivered mail (only the digest is persisted).
  # The mail is multipart, so read a concrete part rather than the container.
  def last_otp_code
    mail = ActionMailer::Base.deliveries.last
    body = (mail.text_part || mail.html_part || mail).body.to_s
    body[/\b\d{6}\b/]
  end

  # Control-plane equivalent of sign_in_as — same real login+OTP shape, but
  # against the completely separate ControlPlane::* auth stack (own cookie,
  # own session model, no tenant/subdomain involved).
  def sign_in_as_platform_admin(admin, password:)
    perform_enqueued_jobs do
      post control_plane_session_path, params: { email: admin.email, password: password }
    end
    post control_plane_email_otp_path, params: { code: last_otp_code }
    follow_redirect!
  end

  # Builds a throwaway tenant + member and signs in through the real flow. The
  # member has NO RoleAssignment rows on purpose: AssignmentSource.from_records
  # returns [] (same as the old nil-institution_user state), so the shared
  # Authorization::StubAssignments persona still drives can?/authorize! exactly
  # as these view tests assert. Returns [user, institution].
  def sign_in_as_member
    slug = "t#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    user = Core::User.create!(email: "#{slug}@member.test", name: "Test Member",
      password: "password-123456")
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      institution.memberships.create!(user: user)
    end
    sign_in_as(user, institution: institution, password: "password-123456")
    [ user, institution ]
  end
end
