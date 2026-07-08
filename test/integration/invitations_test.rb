require "test_helper"

# Registro por invitación: the institution creates the `users` row first (no
# self-registration), IdentityAccess::Invitations::Issuer sends a link scoped
# to the institution's subdomain, and Completer is the only path that ever
# sets that user's password.
class InvitationsTest < ActionDispatch::IntegrationTest
  setup do
    @institution = Core::Institution.create!(name: "Colegio Test", slug: "colegio-test", code: "CT-1", kind: "school")
    @user = Core::User.create!(email: "nueva@colegio.test", name: "Nueva Docente")
    within_tenant(@institution) { @institution.memberships.create!(user: @user) }
  end

  test "issuing invalidates any prior live invitation for the same person" do
    within_tenant(@institution) do
      first = IdentityAccess::Invitations::Issuer.call(user: @user, institution: @institution).invitation
      second = IdentityAccess::Invitations::Issuer.call(user: @user, institution: @institution).invitation

      assert_equal "expired", first.reload.status
      assert_equal "sent", second.status
    end
  end

  test "full flow: opening the emailed link on the institution's subdomain and setting a password logs the user in" do
    perform_enqueued_jobs { issue_invitation }

    host! "colegio-test.example.com"
    get invitation_edit_path_from_last_mail
    assert_response :success
    assert_select "h1", text: "Completa tu cuenta"

    patch invitation_path_from_last_mail, params: { password: "correct-horse-battery", password_confirmation: "correct-horse-battery" }
    assert_redirected_to root_path

    follow_redirect!
    assert_response :success # authenticated, no bounce to login

    assert @user.reload.authenticate("correct-horse-battery")
  end

  test "a mismatched confirmation is rejected and the account stays unusable" do
    perform_enqueued_jobs { issue_invitation }
    host! "colegio-test.example.com"

    patch invitation_path_from_last_mail, params: { password: "correct-horse-battery", password_confirmation: "does-not-match" }
    assert_response :unprocessable_entity
    assert_not @user.reload.authenticate("correct-horse-battery")
  end

  test "a password shorter than 12 characters is rejected" do
    perform_enqueued_jobs { issue_invitation }
    host! "colegio-test.example.com"

    patch invitation_path_from_last_mail, params: { password: "short", password_confirmation: "short" }
    assert_response :unprocessable_entity
  end

  test "a completed invitation cannot be reused" do
    perform_enqueued_jobs { issue_invitation }
    host! "colegio-test.example.com"

    patch invitation_path_from_last_mail, params: { password: "correct-horse-battery", password_confirmation: "correct-horse-battery" }
    delete session_path # log back out

    get invitation_edit_path_from_last_mail
    assert_response :unprocessable_entity
    assert_select "h1", text: /ya no está disponible/
  end

  test "the same token is not usable from a different institution's subdomain (RLS)" do
    perform_enqueued_jobs { issue_invitation }
    Core::Institution.create!(name: "Otro Colegio", slug: "otro-colegio", code: "OC-1", kind: "school")

    host! "otro-colegio.example.com"
    get invitation_edit_path_from_last_mail
    assert_response :unprocessable_entity
    assert_select "h1", text: /ya no está disponible/
  end

  test "reporting a discrepancy writes an audit event and never changes the invitation or the user" do
    perform_enqueued_jobs { issue_invitation }
    host! "colegio-test.example.com"

    before_count = within_tenant(@institution) { IdentityAccess::AuditEvent.count }
    post discrepancy_invitation_path_from_last_mail, params: { message: "Mi nombre está mal escrito" }
    assert_redirected_to invitation_edit_path_from_last_mail

    event = within_tenant(@institution) { IdentityAccess::AuditEvent.find_by(action: "invitation.discrepancy_reported") }
    assert_equal before_count + 1, within_tenant(@institution) { IdentityAccess::AuditEvent.count }
    assert_equal "invitation.discrepancy_reported", event.action
    assert_equal "Mi nombre está mal escrito", event.metadata["message"]
    assert_equal "Nueva Docente", @user.reload.name # untouched
  end

  private

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def issue_invitation
    IdentityAccess::Invitations::Issuer.call(user: @user, institution: @institution)
  end

  def last_invitation_uri
    mail = ActionMailer::Base.deliveries.last
    body = (mail.text_part || mail).body.to_s
    URI(body[%r{https?://\S+}])
  end

  def invitation_edit_path_from_last_mail
    last_invitation_uri.path
  end

  def invitation_path_from_last_mail
    invitation_edit_path_from_last_mail.sub(%r{/edit\z}, "")
  end

  def discrepancy_invitation_path_from_last_mail
    "#{invitation_path_from_last_mail}/discrepancy"
  end
end
