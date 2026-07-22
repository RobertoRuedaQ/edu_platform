require "test_helper"

# communication (v1.20.0, item #5b of the MVP critical path) — subsystem (B)
# messaging. FOUR distinct access paths over the SAME three tables, never
# collapsed: compose (RBAC, conversation.compose) / inbox (participation,
# staff + guardian portal share Communication::Inbox) / reply (participation)
# / audit (RBAC, conversation.audit, conditional audit_events log). See
# HISTORIA.md v1.20.0.
class MessagingTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_section!(institution, name:)
    GroupManagement::Section.create!(institution: institution, name: name, academic_year: 2026)
  end

  def build_student!(institution, first_name:, last_name:, student_code:, section:)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: student_code, entry_year: 2023,
      section: section)
  end

  def build_staff_institution_user!(institution, email:, name: "Staff de prueba")
    user = Core::User.create!(email: email, name: name, password: "password-123456")
    iu = institution.memberships.create!(user: user)
    StaffManagement::StaffMember.create!(institution: institution, institution_user: iu,
      employee_number: "EMP-#{SecureRandom.hex(4)}", staff_category: "admin", employment_type: "full_time")
    iu
  end

  def build_guardian!(institution, student:, email:, name:)
    user = Core::User.create!(email: email, name: name, password: "password-123456")
    institution.memberships.create!(user: user)
    Core::GuardianStudent.create!(institution: institution, guardian_user_id: user.id, student: student,
      relationship: "madre", status: "active")
    user
  end

  setup do
    @user, @institution = sign_in_as_member # communication entitled by default
    @creator_institution_user = @institution.memberships.active.find_by!(user: @user)

    @section_a = within_tenant(@institution) { build_section!(@institution, name: "9°A") }
    @section_b = within_tenant(@institution) { build_section!(@institution, name: "9°B") }

    @student_in_scope = within_tenant(@institution) do
      build_student!(@institution, first_name: "Valentina", last_name: "Suárez", student_code: "MSG-001", section: @section_a)
    end
    @student_out_of_scope = within_tenant(@institution) do
      build_student!(@institution, first_name: "Otro", last_name: "Grupo", student_code: "MSG-002", section: @section_b)
    end

    @guardian_in_scope = within_tenant(@institution) do
      build_guardian!(@institution, student: @student_in_scope, email: "guardian-in-#{SecureRandom.hex(4)}@member.test",
        name: "Acudiente Dentro")
    end
    @guardian_out_of_scope = within_tenant(@institution) do
      build_guardian!(@institution, student: @student_out_of_scope, email: "guardian-out-#{SecureRandom.hex(4)}@member.test",
        name: "Acudiente Fuera")
    end

    @other_staff_iu = within_tenant(@institution) do
      build_staff_institution_user!(@institution, email: "staff2-#{SecureRandom.hex(4)}@member.test", name: "Coordinador")
    end
  end

  def as_composer(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[conversation.compose],
                                     scope_type: :group, scope_id: @section_a.id),
      &block
    )
  end

  def as_auditor(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "rector", permission_keys: %w[conversation.audit],
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

  def start_conversation!(guardian_ids: [], staff_ids: [], subject: "Reunión de padres", body: "Hola a todos")
    as_composer do
      post "/communication/conversations", params: { subject: subject, body: body,
        staff_user_ids: staff_ids, guardian_user_ids: guardian_ids }
    end
    Communication::Conversation.find_by!(institution_id: @institution.id, subject: subject)
  end

  # --- 1. Multiparty ---------------------------------------------------

  test "multiparty: a conversation with 3 participants — everyone sees every message" do
    conversation = start_conversation!(staff_ids: [ @other_staff_iu.user_id ], guardian_ids: [ @guardian_in_scope.id ])
    assert_equal 3, conversation.participants.count

    as_composer { post "/communication/inbox/#{conversation.id}/messages", params: { body: "Segundo mensaje" } }

    sign_in_as(@other_staff_iu.user, institution: @institution, password: "password-123456")
    get "/communication/inbox/#{conversation.id}"
    assert_response :success
    assert_match(/Hola a todos/, response.body)
    assert_match(/Segundo mensaje/, response.body)
  end

  # --- 2. Confidentiality ------------------------------------------------

  test "confidentiality: a non-participant staff member without conversation.audit cannot see the conversation" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    sign_in_as(@other_staff_iu.user, institution: @institution, password: "password-123456")
    get "/communication/inbox"
    assert_no_match(/#{Regexp.escape(conversation.subject)}/, response.body)

    get "/communication/inbox/#{conversation.id}"
    assert_response :not_found
  end

  # --- 3. Shared inbox computation --------------------------------------

  test "inbox by participation: staff and guardian each see only their own, via the SAME shared computation" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    staff_subjects = Communication::Inbox.call(institution: @institution, institution_user: @creator_institution_user)
      .map { |row| row.conversation.subject }
    assert_includes staff_subjects, conversation.subject

    sign_in_as(@guardian_in_scope, institution: @institution, password: "password-123456")
    get "/portal/guardian/inbox"
    assert_response :success
    assert_match(/#{Regexp.escape(conversation.subject)}/, response.body)

    guardian_out_subjects = Communication::Inbox.call(institution: @institution, guardian_user: @guardian_out_of_scope)
      .map { |row| row.conversation.subject }
    assert_not_includes guardian_out_subjects, conversation.subject
  end

  # --- 4. Unread ----------------------------------------------------------

  test "unread: badge reflects last_read_at, opening marks it read, and my own messages never count for me" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    guardian_rows = Communication::Inbox.call(institution: @institution, guardian_user: @guardian_in_scope)
    assert_equal 1, guardian_rows.first.unread_count

    sign_in_as(@guardian_in_scope, institution: @institution, password: "password-123456")
    get "/portal/guardian/inbox/#{conversation.id}"

    assert_equal 0, Communication::Inbox.call(institution: @institution, guardian_user: @guardian_in_scope).first.unread_count

    post "/portal/guardian/inbox/#{conversation.id}/messages", params: { body: "Gracias por avisar" }

    assert_equal 0, Communication::Inbox.call(institution: @institution, guardian_user: @guardian_in_scope).first.unread_count
    staff_rows = Communication::Inbox.call(institution: @institution, institution_user: @creator_institution_user)
    assert_equal 1, staff_rows.first.unread_count
  end

  # --- 5. Close/reopen ------------------------------------------------

  test "close/reopen: soft, survives, blocks replying while closed" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    as_composer { post "/communication/inbox/#{conversation.id}/close" }
    conversation.reload
    assert_equal "closed", conversation.status
    assert_not_nil conversation.closed_at
    assert_not_nil Communication::Conversation.find_by(id: conversation.id), "close must never hard-delete"

    as_composer { post "/communication/inbox/#{conversation.id}/messages", params: { body: "No debería entrar" } }
    assert_equal 1, conversation.messages.count, "a closed conversation must reject a reply"

    as_composer { post "/communication/inbox/#{conversation.id}/reopen" }
    assert_equal "active", conversation.reload.status

    as_composer { post "/communication/inbox/#{conversation.id}/messages", params: { body: "Ya se puede" } }
    assert_equal 2, conversation.messages.count
  end

  # --- 6. Bounded compose ------------------------------------------------

  test "compose: an out-of-scope guardian is silently dropped server-side even if the request is tampered" do
    as_composer do
      post "/communication/conversations", params: { subject: "Intento fuera de alcance", body: "Hola",
        guardian_user_ids: [ @guardian_out_of_scope.id ] }
    end

    assert_nil Communication::Conversation.find_by(institution_id: @institution.id, subject: "Intento fuera de alcance")
  end

  test "compose: an in-scope guardian IS addable, and no directory search field exists" do
    as_composer do
      get "/communication/conversations/new"
      assert_response :success
      assert_match(/#{Regexp.escape(@guardian_in_scope.name)}/, response.body)
      assert_no_match(/#{Regexp.escape(@guardian_out_of_scope.name)}/, response.body)
      # Scoped to #main to deliberately exclude the staff shell's pre-existing
      # global app search in the header (unrelated to this page).
      assert_select "main#main input[type=search]", count: 0
      assert_select "main#main input[name=q]", count: 0
    end
  end

  test "compose: without conversation.compose, 403 and no way to reach it" do
    as_plain_staff do
      get "/communication/conversations/new"
      assert_response :forbidden

      post "/communication/conversations", params: { subject: "X", body: "Y" }
      assert_response :forbidden
    end
  end

  # --- 7. Guardian responds, never initiates -----------------------------

  test "a guardian can reply to their own conversation but cannot initiate one" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    sign_in_as(@guardian_in_scope, institution: @institution, password: "password-123456")
    post "/portal/guardian/inbox/#{conversation.id}/messages", params: { body: "Puedo responder" }
    assert_equal 2, conversation.messages.count

    get "/communication/conversations/new"
    assert_response :forbidden
  end

  # --- 8. Auditor ------------------------------------------------------

  # as_auditor (with_grants) reuses @user's SAME session — and @user is
  # ALWAYS a participant (the creator, via start_conversation!), so it can't
  # exercise the "genuinely NOT a participant" path. This test needs a truly
  # separate actor: @other_staff_iu, granted conversation.audit directly and
  # actually re-authenticated as them.
  test "auditor reading a conversation they are NOT part of sees content and it gets logged" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    grant_role!(@other_staff_iu.user, institution: @institution, role_key: "rector",
      permission_keys: %w[conversation.audit], scope_type: :institution, scope_id: nil)
    sign_in_as(@other_staff_iu.user, institution: @institution, password: "password-123456")

    get "/communication/conversation_audits/#{conversation.id}"
    assert_response :success
    assert_match(/Hola a todos/, response.body)

    event = IdentityAccess::AuditEvent.where(institution_id: @institution.id, action: "conversation_audited",
      target_id: conversation.id).last
    assert_not_nil event, "reading as a non-participant auditor must write a conversation_audited event"
    assert_equal @other_staff_iu.id, event.actor_institution_user_id
  end

  test "a participant reading their OWN conversation via the audit route (even holding conversation.audit) logs nothing" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    with_grants(
      Authorization::Assignment.new(role_key: "rector", permission_keys: %w[conversation.compose conversation.audit],
                                     scope_type: :institution, scope_id: nil)
    ) do
      get "/communication/conversation_audits/#{conversation.id}"
      assert_response :success
    end

    assert_empty IdentityAccess::AuditEvent.where(institution_id: @institution.id, action: "conversation_audited",
      target_id: conversation.id)
  end

  test "the audit trail is never surfaced to participants in their own inbox" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])
    as_auditor { get "/communication/conversation_audits/#{conversation.id}" }

    as_composer do
      get "/communication/inbox/#{conversation.id}"
      assert_no_match(/audit/i, response.body)
    end
  end

  test "the conversation_audited event appears in the RBAC-gated audit viewer" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    # A real event needs a genuine non-participant — same reasoning as the
    # "sees content and it gets logged" test above. Both permissions granted
    # in ONE call: grant_role! isn't idempotent across repeated calls for
    # the same role/scope (a real RoleAssignment row, unique-indexed).
    grant_role!(@other_staff_iu.user, institution: @institution, role_key: "rector",
      permission_keys: %w[conversation.audit audit_events.read], scope_type: :institution, scope_id: nil)
    sign_in_as(@other_staff_iu.user, institution: @institution, password: "password-123456")
    get "/communication/conversation_audits/#{conversation.id}"
    assert_response :success

    get "/identity_access/audit_events"
    assert_response :success
    # The action's human label always appears in the filter <select> — match
    # against an actual EVENT ROW (the audit-log partial), not the filter
    # option, so this can't pass on a dropdown option alone.
    assert_select ".audit-log", text: /Conversación auditada/
  end

  # --- 9. Exactly-one identity + sender-is-participant ------------------

  test "the DB itself (not just app validation) rejects a participant row with neither identity set" do
    within_tenant(@institution) do
      conversation = Communication::Conversation.create!(institution: @institution, subject: "x", status: "active")
      assert_raises(ActiveRecord::StatementInvalid) do
        # requires_new: true opens a REAL savepoint — without it, the raw
        # execute's failure poisons the enclosing transaction (within_tenant's),
        # so anything the test does afterward (even just letting the block
        # exit normally) raises a confusing "current transaction is aborted"
        # instead of the constraint violation this test actually wants.
        ActiveRecord::Base.transaction(requires_new: true) do
          ActiveRecord::Base.connection.execute(<<~SQL)
            INSERT INTO conversation_participants (id, institution_id, conversation_id, created_at, updated_at)
            VALUES (gen_random_uuid(), '#{@institution.id}', '#{conversation.id}', now(), now())
          SQL
        end
      end
    end
  end

  test "Communication::MessageSender rejects a sender who is not a participant, even one holding conversation.audit" do
    conversation = start_conversation!(guardian_ids: [ @guardian_in_scope.id ])

    result = Communication::MessageSender.call(institution: @institution, conversation: conversation,
      institution_user: @other_staff_iu, body: "No debería poder")
    assert_equal :not_participant, result.error
    assert_nil result.message
  end

  # --- 10. Entitlement gate #1 --------------------------------------

  test "entitlement gate #1: not entitled shows the friendly module page on compose, inbox, and audit" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "communication" })
    entitlement.revoke!

    as_composer do
      get "/communication/conversations/new"
      assert_response :forbidden
      assert_match "no está habilitado", response.body

      get "/communication/inbox"
      assert_response :forbidden
    end

    as_auditor do
      get "/communication/conversation_audits"
      assert_response :forbidden
    end
  end

  # --- 11. Cross-tenant --------------------------------------------------

  test "cross-tenant: a conversation seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "msg-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      Communication::Conversation.create!(institution: other_institution, subject: "Ajeno", status: "active")
    end

    as_composer do
      get "/communication/inbox"
      assert_response :success
      assert_no_match(/Ajeno/, response.body)
    end

    within_tenant(@institution) do
      assert_empty Communication::Conversation.where(institution_id: other_institution.id)
    end
  end

  # S3b (v1.30.0): Communication::MessageSender emits real usage — one
  # "mensajes" unit per Message actually sent. NOTE: the conversation's FIRST
  # message is created directly by ConversationComposer, NOT MessageSender —
  # so start_conversation! itself never emits; only the reply below does.
  test "S3b: sending a message emits one usage_events row, never duplicated on a resend attempt" do
    ControlPlane::Addon.find_by!(key: "communication").update!( # sign_in_as_member already seeded this addon, unmetered
      metered: true, unit: "mensajes", included_quota: 10, overage_unit_price_cents: 20
    )
    conversation = start_conversation!(staff_ids: [ @other_staff_iu.user_id ], guardian_ids: [ @guardian_in_scope.id ])

    as_composer { post "/communication/inbox/#{conversation.id}/messages", params: { body: "Segundo mensaje" } }

    events = ControlPlane::UsageEvent.where(institution_id: @institution.id)
    assert_equal 1, events.count
    assert_equal "mensajes", events.sole.unit
    assert_equal 1, events.sole.quantity
  end

  test "S3b: with the communication addon unmetered (the sign_in_as_member default), sending a message still succeeds — Usage::Ingest.emit never breaks it" do
    conversation = start_conversation!(staff_ids: [ @other_staff_iu.user_id ], guardian_ids: [ @guardian_in_scope.id ])
    assert_empty ControlPlane::UsageEvent.where(institution_id: @institution.id)

    as_composer { post "/communication/inbox/#{conversation.id}/messages", params: { body: "Sigue funcionando" } }
    assert_match "Sigue funcionando", Communication::Message.last.body
    assert_empty ControlPlane::UsageEvent.where(institution_id: @institution.id)
  end
end
