require "test_helper"

# communication (v1.19.0, item #5 of the MVP critical path) — subsystem (A)
# anuncios only. Two DISTINCT gates: publish/manage is RBAC
# (announcement.publish + Navigation::Registry); read is MEMBERSHIP (any
# active member, no authorize!, outside the Registry) — a third gate type
# alongside RBAC and self-service/relation (see Guardrails). Messaging (B)
# is a future slice, not built here.
class CommunicationTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  setup { @user, @institution = sign_in_as_member } # communication entitled by default (grant_full_entitlements)

  def as_comms(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "comms_lead", permission_keys: %w[announcement.publish],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_plain_staff(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[grades.read],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def publish_announcement!(title: "Aviso", body: "Cuerpo del aviso")
    as_comms do
      post "/communication/announcements", params: { announcement: { title: title, body: body } }
    end
    Communication::Announcement.find_by!(institution_id: @institution.id, title: title)
  end

  test "publishing requires announcement.publish; without it, 403 and no nav tile" do
    as_plain_staff do
      post "/communication/announcements", params: { announcement: { title: "X", body: "Y" } }
      assert_response :forbidden

      get "/"
      assert_select "a.app-nav__link", text: "Anuncios (gestión)", count: 0
    end
  end

  test "acceptance: publishing creates a published announcement with author attribution" do
    as_comms do
      post "/communication/announcements", params: { announcement: { title: "Reunión de padres", body: "El viernes a las 6pm." } }
      assert_redirected_to communication_announcements_path
    end

    announcement = Communication::Announcement.find_by!(institution_id: @institution.id, title: "Reunión de padres")
    assert_equal "published", announcement.status
    assert_not_nil announcement.published_at
    assert_equal @institution.memberships.active.find_by!(user: @user).id, announcement.author_institution_user_id
  end

  test "editing an announcement requires announcement.publish too" do
    announcement = publish_announcement!

    as_plain_staff do
      get "/communication/announcements/#{announcement.id}/edit"
      assert_response :forbidden
    end

    as_comms do
      patch "/communication/announcements/#{announcement.id}", params: { announcement: { title: "Editado" } }
      assert_equal "Editado", announcement.reload.title
    end
  end

  test "retract is soft: the announcement disappears from the feed but the row survives" do
    announcement = publish_announcement!

    as_comms { post "/communication/announcements/#{announcement.id}/retract" }

    announcement.reload
    assert_equal "retracted", announcement.status
    assert_not_nil announcement.retracted_at
    assert_not_nil Communication::Announcement.find_by(id: announcement.id), "retract must never hard-delete"
    assert_not_includes Communication::AnnouncementFeed.call(institution: @institution), announcement
  end

  test "membership read: a staff member WITHOUT announcement.publish still sees published announcements" do
    publish_announcement!(title: "Para todos")

    as_plain_staff do
      get "/communication/feed"
      assert_response :success
      assert_match(/Para todos/, response.body)
    end
  end

  test "retracted announcements never appear in the staff feed" do
    announcement = publish_announcement!(title: "Se retracta")
    as_comms { post "/communication/announcements/#{announcement.id}/retract" }

    as_plain_staff do
      get "/communication/feed"
      assert_no_match(/Se retracta/, response.body)
    end
  end

  test "portal (guardian): sees published announcements, org-wide, without any relation to a child" do
    publish_announcement!(title: "Aviso institucional")

    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      user
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/announcements"
    assert_response :success
    assert_match(/Aviso institucional/, response.body)
  end

  test "portal (student): sees published announcements even with no linked GroupManagement::Student" do
    publish_announcement!(title: "Aviso para estudiantes")

    student_user = within_tenant(@institution) do
      user = Core::User.create!(email: "student-#{SecureRandom.hex(4)}@member.test", name: "Estudiante Suelto",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      user
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/announcements"
    assert_response :success
    assert_match(/Aviso para estudiantes/, response.body)
  end

  test "shared read path: staff feed and portal feed return the exact same set" do
    publish_announcement!(title: "Uno")
    publish_announcement!(title: "Dos")
    retracted = publish_announcement!(title: "Tres")
    as_comms { post "/communication/announcements/#{retracted.id}/retract" }

    staff_titles = as_plain_staff do
      get "/communication/feed"
      Communication::AnnouncementFeed.call(institution: @institution).pluck(:title)
    end

    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian2-#{SecureRandom.hex(4)}@member.test", name: "Acudiente 2",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      user
    end
    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/announcements"
    assert_match(/Uno/, response.body)
    assert_match(/Dos/, response.body)
    assert_no_match(/Tres/, response.body)

    assert_equal Set[ "Uno", "Dos" ], staff_titles.to_set
  end

  test "entitlement gate #1 on the management surface: not entitled shows the friendly module page" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "communication" })
    entitlement.revoke!

    as_comms do
      get "/communication/announcements"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "entitlement gate #1 on the staff feed too" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "communication" })
    entitlement.revoke!

    as_plain_staff do
      get "/communication/feed"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "DOCUMENTED GAP: the portal read surface does NOT check entitlement (same accepted gap as report_cards/finance)" do
    publish_announcement!(title: "Visible sin entitlement")
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "communication" })
    entitlement.revoke!

    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian3-#{SecureRandom.hex(4)}@member.test", name: "Acudiente 3",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      user
    end
    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/announcements"
    assert_response :success # NOT forbidden — Portals::* is never registered in Entitlement::Registry
    assert_match(/Visible sin entitlement/, response.body)
  end

  test "cross-tenant: an announcement seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "comm-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      Communication::Announcement.create!(institution: other_institution, title: "Ajeno",
        body: "No debería verse", status: "published", published_at: Time.current)
    end

    as_plain_staff do
      get "/communication/feed"
      assert_response :success
      assert_no_match(/Ajeno/, response.body)
    end

    within_tenant(@institution) do
      assert_empty Communication::Announcement.where(institution_id: other_institution.id)
    end
  end
end
