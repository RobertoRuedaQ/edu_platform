require "test_helper"

# The acceptance case (§5): the audit viewer + discrepancy inbox must be
# RBAC-gated (the OPPOSITE of self-service's identity-gating), tenant-scoped,
# filterable without becoming a people-search surface, and append-only.
class AuditEventsTest < ActionDispatch::IntegrationTest
  setup { @user, @institution = sign_in_as_member }

  def as_auditor(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[audit_events.read],
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

  def seed_event!(institution, actor:, action:, created_at: Time.current)
    IdentityAccess::AuditEvent.create!(institution: institution, actor_institution_user: actor,
      action: action, created_at: created_at)
  end

  test "403 without audit_events.read — the hard gate is present" do
    with_grants do
      get "/identity_access/audit_events"
      assert_response :forbidden

      get "/identity_access/audit_events/discrepancies"
      assert_response :forbidden
    end
  end

  test "acceptance: filters compose, the discrepancy inbox is exact, cross-tenant never leaks, pagination works" do
    institution_j = Core::Institution.create!(name: "Colegio J", slug: "aud-j-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    admin_a = within_tenant(@institution) { @institution.memberships.find_by(user: @user) }
    other_user = Core::User.create!(email: "other-#{SecureRandom.hex(3)}@correo.test", name: "Otro Staff")
    admin_other = within_tenant(@institution) { @institution.memberships.create!(user: other_user) }

    within_tenant(@institution) do
      seed_event!(@institution, actor: admin_a, action: "person.created", created_at: 10.days.ago)
      seed_event!(@institution, actor: admin_other, action: "person.suspended", created_at: 5.days.ago)
      seed_event!(@institution, actor: admin_a, action: IdentityAccess::AuditEventIndex::DISCREPANCY_ACTION, created_at: 1.day.ago)
    end

    # Same shapes of events, replicated in institution J — must never surface from I.
    within_tenant(institution_j) do
      iu_j = institution_j.memberships.create!(user: Core::User.create!(email: "j-#{SecureRandom.hex(3)}@correo.test", name: "Solo En J"))
      seed_event!(institution_j, actor: iu_j, action: "person.created")
      seed_event!(institution_j, actor: iu_j, action: IdentityAccess::AuditEventIndex::DISCREPANCY_ACTION)
    end

    as_auditor do
      get "/identity_access/audit_events"
      assert_response :success
      assert_select ".audit-entry", count: 3
      assert_no_match(/Solo En J/, response.body)

      # Filter by actor.
      get "/identity_access/audit_events", params: { actor_institution_user_id: admin_other.id }
      assert_response :success
      assert_select ".audit-entry", count: 1

      # Filter by action.
      get "/identity_access/audit_events", params: { action_key: "person.created" }
      assert_response :success
      assert_select ".audit-entry", count: 1

      # Filter by date range excludes the oldest event.
      get "/identity_access/audit_events", params: { from: 6.days.ago.to_date.iso8601, to: Date.current.iso8601 }
      assert_response :success
      assert_select ".audit-entry", count: 2

      # Filter with no matches -> empty state, not an error.
      get "/identity_access/audit_events", params: { action_key: "roster_import.validated" }
      assert_response :success
      assert_select ".empty-state__title"

      # The discrepancy inbox shows EXACTLY the discrepancy marker, nothing else.
      get "/identity_access/audit_events/discrepancies"
      assert_response :success
      assert_select ".audit-entry", count: 1
      assert_no_match(/Solo En J/, response.body)
    end
  end

  test "pagination limits a single page and links to the next" do
    within_tenant(@institution) do
      actor = @institution.memberships.find_by(user: @user)
      (IdentityAccess::AuditEventIndex::PER_PAGE + 5).times { seed_event!(@institution, actor: actor, action: "person.created") }
    end

    as_auditor do
      get "/identity_access/audit_events"
      assert_response :success
      assert_select ".audit-entry", count: IdentityAccess::AuditEventIndex::PER_PAGE
      assert_select ".pagination__link", text: "2"

      get "/identity_access/audit_events", params: { page: 2 }
      assert_response :success
      assert_select ".audit-entry", count: 5
    end
  end

  test "no people/student search surface anywhere in the viewer or the inbox (Habeas Data)" do
    as_auditor do
      get "/identity_access/audit_events"
      assert_response :success
      # Scoped to #main to deliberately exclude the staff shell's pre-existing
      # global app search in the header (unrelated to this page, out of
      # scope — same call self_service_test.rb already made).
      assert_select "main#main input[type=search]", count: 0
      assert_select "main#main input[name=q]", count: 0
      # The actor filter is a closed <select> over the institution's own
      # staff, never a free-text/autocomplete field.
      assert_select "select#audit-actor"
      assert_select "input[name=actor_institution_user_id]", count: 0

      get "/identity_access/audit_events/discrepancies"
      assert_response :success
      assert_select "main#main input[type=search]", count: 0
    end
  end

  test "append-only: no route or controller action exists to update or destroy an audit event" do
    routes = Rails.application.routes.routes.select { |r| r.defaults[:controller] == "identity_access/audit_events" }
    assert_equal %w[discrepancies index], routes.map { |r| r.defaults[:action] }.sort

    controller_methods = IdentityAccess::AuditEventsController.instance_methods(false)
    assert_not_includes controller_methods, :update
    assert_not_includes controller_methods, :destroy
    assert_not_includes controller_methods, :create
  end
end
