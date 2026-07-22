require "test_helper"

# Real BYPASSRLS wiring (v1.35.0, BI_DOCUMENT.md §6.1 Slice 1) — first real
# cross-tenant query in the app. AnalyticsBi::CrossTenantReportRoster runs
# through a genuinely SEPARATE database connection (edu_bi_reader), which
# means it can NEVER see another connection's uncommitted transaction —
# Rails' standard transactional-test rollback is invisible to it. This test
# class deliberately disables transactional tests and MUST clean up every
# row it creates by hand in teardown — nothing here rolls back on its own,
# and the suite runs in series (never parallel, see OPEN_PROCESS.md), so
# there's no concurrent test to race against during that cleanup.
#
# Real pollution found and fixed while writing this test: an earlier draft
# called grant_full_entitlements (creates ALL 13 domain Addon rows for
# real) with no teardown at all — leftover global Addon/Institution/User
# rows then collided (UNIQUE key violations) with dozens of unrelated
# transactional tests later in the SAME suite run. Fixed by (a) granting
# only the ONE addon this test actually needs, and (b) a teardown that
# deletes everything, in FK-safe order.
class AnalyticsBiCrossTenantTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  PASSWORD = "password-123456".freeze

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def as_bi_auditor(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "bi_auditor", permission_keys: %w[cross_tenant_reports.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  teardown do
    ControlPlane::Entitlement.where(institution_id: @institutions&.map(&:id)).delete_all if @institutions
    @addon&.destroy
    @institutions&.each do |institution|
      within_tenant(institution) do
        GroupManagement::Student.where(institution_id: institution.id).delete_all
        IdentityAccess::RoleAssignment.where(institution_id: institution.id).delete_all
        IdentityAccess::RolePermission.where(institution_id: institution.id).delete_all
        IdentityAccess::Role.where(institution_id: institution.id).delete_all
        Core::InstitutionUser.where(institution_id: institution.id).delete_all
      end
    end
    @user&.destroy # cascades its Core::Session rows (dependent: :destroy)
    @institutions&.each(&:destroy) # audit_events referencing institution_id never block this (confirmed empirically)
  end

  test "acceptance: the cross-tenant report shows real per-institution aggregates, grouped, never blended, and audits the access" do
    institution_a = Core::Institution.create!(name: "Colegio BI Uno #{SecureRandom.hex(4)}",
      slug: "bi-one-#{SecureRandom.hex(4)}", code: "BI1-#{SecureRandom.hex(3)}", kind: "school")
    institution_b = Core::Institution.create!(name: "Colegio BI Dos #{SecureRandom.hex(4)}",
      slug: "bi-two-#{SecureRandom.hex(4)}", code: "BI2-#{SecureRandom.hex(3)}", kind: "school")
    @institutions = [ institution_a, institution_b ]

    user = Core::User.create!(email: "bi-auditor-#{SecureRandom.hex(4)}@member.test", name: "Auditor BI", password: PASSWORD)
    @user = user
    within_tenant(institution_a) { institution_a.memberships.create!(user: user) }

    # Only the ONE addon this test needs (never grant_full_entitlements —
    # see the class docstring on why that polluted the whole suite).
    @addon = ControlPlane::Addon.create!(key: "analytics_bi", name: "Analítica y BI", currency: "COP")
    ControlPlane::Entitlement.create!(institution: institution_a, addon: @addon, valid_from: 1.day.ago.to_date)

    within_tenant(institution_a) do
      2.times do |i|
        GroupManagement::Student.create!(institution: institution_a, first_name: "Est", last_name: "A#{i}",
          gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "BIX-#{SecureRandom.hex(4)}",
          entry_year: 2023, status: "active")
      end
    end
    within_tenant(institution_b) do
      GroupManagement::Student.create!(institution: institution_b, first_name: "Est", last_name: "B0",
        gender: "male", birthdate: Date.new(2013, 3, 1), student_code: "BIY-#{SecureRandom.hex(4)}",
        entry_year: 2023, status: "active")
    end

    # with_grants uses @user/@institution instance vars (see test_helper.rb),
    # not Current — must be set for a non-sign_in_as_member flow like this one.
    @institution = institution_a

    sign_in_as(user, institution: institution_a, password: PASSWORD)
    # Without Rails' transactional-test wrapper, grant_role!'s own GUC only
    # lives for the length of its own real (committing) transaction — the
    # "leaks forward across statements" convenience every OTHER test gets
    # for free from the outer rolled-back transaction's savepoint semantics
    # doesn't apply here. Set it explicitly for with_grants' sake; the HTTP
    # request itself resolves its own tenant via subdomain regardless.
    within_tenant(institution_a) do
      as_bi_auditor do
        get "/analytics_bi/cross_tenant_reports"
        assert_response :success
        assert_match institution_a.name, response.body
        assert_match institution_b.name, response.body
        # Aggregates only, grouped correctly per institution — never blended
        # into one number (2 here, 1 there — never 3 for both, never 0).
        assert_select "td", text: "2"
        assert_select "td", text: "1"
      end
    end

    within_tenant(institution_a) do
      assert IdentityAccess::AuditEvent.exists?(institution_id: institution_a.id, action: "cross_tenant_report_accessed")
    end
  end
end
