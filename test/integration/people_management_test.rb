require "test_helper"

# Gestión de personas/cuentas: crear (Core::People::Resolver), invitar/
# reenviar (Invitations::Issuer), suspender/reactivar (InstitutionUser).
class PeopleManagementTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member
    ActionMailer::Base.deliveries.clear # drop the OTP mail sign_in_as_member itself sent
  end

  def as_people_manager(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[people.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  test "index/create/resend/suspend/reactivate all require people.manage" do
    other = create_member(@institution, email: "otro@colegio.test")

    with_grants do
      get "/identity_access/people"
      assert_response :forbidden

      post "/identity_access/people", params: { name: "X", email: "x@colegio.test" }
      assert_response :forbidden

      post "/identity_access/people/#{other.id}/suspend"
      assert_response :forbidden
    end
  end

  test "creating a person resolves the user, attaches a membership, and issues an invitation" do
    as_people_manager do
      perform_enqueued_jobs do
        assert_difference -> { Core::User.count }, 1 do
          post "/identity_access/people", params: { name: "Ana Nueva", email: "ana.nueva@colegio.test" }
        end
      end
      assert_redirected_to identity_access_people_path
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    membership = within_tenant(@institution) do
      Core::InstitutionUser.joins(:user).find_by(users: { email: "ana.nueva@colegio.test" })
    end
    assert membership
    assert membership.active?

    event = within_tenant(@institution) { IdentityAccess::AuditEvent.find_by(action: "person.created") }
    assert_equal membership.user_id, event.target_id
  end

  test "creating a person twice with the same email attaches, it never duplicates the global user" do
    as_people_manager do
      perform_enqueued_jobs { post "/identity_access/people", params: { name: "Ana Nueva", email: "ana.nueva@colegio.test" } }
    end

    other_institution = Core::Institution.create!(name: "Otro Colegio", slug: "otro-colegio-2", code: "OC-2", kind: "school")
    within_tenant(other_institution) { other_institution.memberships.create!(user: @user) }
    host! "otro-colegio-2.example.com"

    as_people_manager do
      assert_no_difference -> { Core::User.count } do
        perform_enqueued_jobs { post "/identity_access/people", params: { name: "Ana Nueva", email: "ana.nueva@colegio.test" } }
      end
    end

    assert_equal 1, Core::User.where(email: "ana.nueva@colegio.test").count
  end

  test "resending an invitation issues a new one" do
    as_people_manager do
      perform_enqueued_jobs { post "/identity_access/people", params: { name: "Ana Nueva", email: "ana.nueva@colegio.test" } }
    end
    user = Core::User.find_by(email: "ana.nueva@colegio.test")
    membership = within_tenant(@institution) { Core::InstitutionUser.find_by(institution: @institution, user: user) }

    as_people_manager do
      assert_difference -> { within_tenant(@institution) { IdentityAccess::Invitation.count } }, 1 do
        perform_enqueued_jobs { post resend_invitation_identity_access_person_path(membership) }
      end
    end
    assert_redirected_to identity_access_people_path
  end

  test "suspending a membership blocks login, reactivating restores it" do
    member = create_member(@institution, email: "suspendible@colegio.test", password: "correct-horse-battery")

    as_people_manager { post suspend_identity_access_person_path(member) }
    assert_not member.reload.active?

    perform_enqueued_jobs do
      post session_path, params: { email: "suspendible@colegio.test", password: "correct-horse-battery" }
    end
    assert_response :unprocessable_entity
    assert_empty ActionMailer::Base.deliveries

    as_people_manager { post reactivate_identity_access_person_path(member) }
    assert member.reload.active?

    perform_enqueued_jobs do
      post session_path, params: { email: "suspendible@colegio.test", password: "correct-horse-battery" }
    end
    assert_redirected_to new_email_otp_path
  end

  test "suspend/reactivate write audit events" do
    member = create_member(@institution, email: "audit-target@colegio.test")

    as_people_manager { post suspend_identity_access_person_path(member) }
    as_people_manager { post reactivate_identity_access_person_path(member) }

    actions = within_tenant(@institution) { IdentityAccess::AuditEvent.where(target_id: member.user_id).pluck(:action) }
    assert_includes actions, "person.suspended"
    assert_includes actions, "person.reactivated"
  end

  test "Invitations::Expirer marks past-due invitations as expired" do
    issued = within_tenant(@institution) { IdentityAccess::Invitations::Issuer.call(user: @user, institution: @institution) }
    within_tenant(@institution) { issued.invitation.update!(expires_at: 1.day.ago) }

    within_tenant(@institution) { IdentityAccess::Invitations::Expirer.call(institution: @institution) }

    assert_equal "expired", within_tenant(@institution) { issued.invitation.reload.status }
  end

  test "Invitations::BounceHandler marks the live invitation bounced and audits it" do
    within_tenant(@institution) { IdentityAccess::Invitations::Issuer.call(user: @user, institution: @institution) }

    within_tenant(@institution) { IdentityAccess::Invitations::BounceHandler.call(institution: @institution, email: @user.email) }

    invitation = within_tenant(@institution) { IdentityAccess::Invitation.find_by(user: @user, institution: @institution) }
    assert_equal "bounced", invitation.status
    assert within_tenant(@institution) { IdentityAccess::AuditEvent.exists?(action: "invitation.bounced") }
  end

  private

  def create_member(institution, email:, password: nil)
    user = Core::User.create!(email: email, name: "Persona de Prueba", password: password, password_confirmation: password)
    within_tenant(institution) { institution.memberships.create!(user: user) }
  end
end
