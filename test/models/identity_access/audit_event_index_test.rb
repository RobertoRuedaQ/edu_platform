require "test_helper"

class IdentityAccess::AuditEventIndexTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "aei-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_actor!(institution)
    user = Core::User.create!(email: "actor-#{SecureRandom.hex(4)}@correo.test", name: "Actor #{SecureRandom.hex(2)}")
    institution.memberships.create!(user: user)
  end

  test "scopes to the given institution only, never a different tenant" do
    institution_i = build_institution
    institution_j = build_institution

    within_tenant(institution_i) do
      actor = build_actor!(institution_i)
      IdentityAccess::Audit.log(institution: institution_i, actor_institution_user: actor, action: "person.created")
    end
    within_tenant(institution_j) do
      actor = build_actor!(institution_j)
      IdentityAccess::Audit.log(institution: institution_j, actor_institution_user: actor, action: "person.created")
    end

    within_tenant(institution_i) do
      page = IdentityAccess::AuditEventIndex.call(institution: institution_i)
      assert_equal 1, page.total_count
      assert_equal institution_i.id, page.events.first.institution_id
    end
  end

  test "filters by actor" do
    institution = build_institution
    within_tenant(institution) do
      actor_a = build_actor!(institution)
      actor_b = build_actor!(institution)
      IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor_a, action: "person.created")
      IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor_b, action: "person.created")

      page = IdentityAccess::AuditEventIndex.call(institution: institution, actor_institution_user_id: actor_a.id)
      assert_equal 1, page.total_count
      assert_equal actor_a.id, page.events.first.actor_institution_user_id
    end
  end

  test "filters by action, ignoring an action outside the known set" do
    institution = build_institution
    within_tenant(institution) do
      actor = build_actor!(institution)
      IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor, action: "person.created")
      IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor, action: "person.suspended")

      page = IdentityAccess::AuditEventIndex.call(institution: institution, action: "person.suspended")
      assert_equal 1, page.total_count
      assert_equal "person.suspended", page.events.first.action

      # An action outside ACTIONS is silently ignored (AV5 — no free-text
      # filter), so this returns everything rather than erroring.
      page_all = IdentityAccess::AuditEventIndex.call(institution: institution, action: "'; DROP TABLE audit_events;--")
      assert_equal 2, page_all.total_count
    end
  end

  test "filters by date range, composing with the other filters" do
    institution = build_institution
    within_tenant(institution) do
      actor = build_actor!(institution)
      # audit_events is append-only (runtime has no UPDATE grant — see the
      # original migration), so an "old" row must be INSERTed with an
      # explicit created_at, never built then updated.
      IdentityAccess::AuditEvent.create!(institution: institution, actor_institution_user: actor,
        action: "person.created", created_at: 30.days.ago)
      IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor, action: "person.created")

      page = IdentityAccess::AuditEventIndex.call(institution: institution, from: 5.days.ago.to_date, to: Date.current)
      assert_equal 1, page.total_count
    end
  end

  test "the discrepancy inbox pre-filter returns exactly the discrepancy marker, nothing else" do
    institution = build_institution
    within_tenant(institution) do
      actor = build_actor!(institution)
      IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor, action: "person.created")
      IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor,
        action: IdentityAccess::AuditEventIndex::DISCREPANCY_ACTION)

      page = IdentityAccess::AuditEventIndex.call(institution: institution, action: IdentityAccess::AuditEventIndex::DISCREPANCY_ACTION)
      assert_equal 1, page.total_count
      assert_equal IdentityAccess::AuditEventIndex::DISCREPANCY_ACTION, page.events.first.action
    end
  end

  test "paginates in descending order without loading the whole table" do
    institution = build_institution
    within_tenant(institution) do
      actor = build_actor!(institution)
      30.times { |n| IdentityAccess::Audit.log(institution: institution, actor_institution_user: actor, action: "person.created") }

      page1 = IdentityAccess::AuditEventIndex.call(institution: institution, page: 1)
      assert_equal IdentityAccess::AuditEventIndex::PER_PAGE, page1.events.size
      assert_equal 2, page1.total_pages
      assert_equal 30, page1.total_count

      page2 = IdentityAccess::AuditEventIndex.call(institution: institution, page: 2)
      assert_equal 5, page2.events.size

      assert_empty page1.events.map(&:id) & page2.events.map(&:id)
    end
  end

  test "returns an empty page for a nil institution, never an error" do
    page = IdentityAccess::AuditEventIndex.call(institution: nil)
    assert_empty page.events
    assert_equal 0, page.total_count
  end
end
