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

  # Builds a throwaway tenant + member and signs in through the real flow.
  #
  # P1 (real RBAC): the member gets a real, institution-wide IdentityAccess::
  # RoleAssignment by default (grant_default_role: false opts out, for tests
  # that need to observe a truly grant-less actor — R2 fail-closed). The
  # default's permission set mirrors the OLD Authorization::StubAssignments
  # persona (students/grades/staff/counseling reads) so every preexisting view
  # test written against that persona keeps passing unedited — this is the
  # ONE shared place that absorbs the "real-only" impact, per R-tests. It is
  # institution-wide on purpose: covers?  short-circuits on scope_type
  # :institution, so it authorizes across every domain's resources regardless
  # of that domain's own (still-stub) scope id shape — no need to touch every
  # domain's roster just to satisfy this default. Tests that need a NARROWER,
  # scope-specific persona (e.g. "only sees their own section") call
  # grant_role! themselves for the specific scope under test.
  #
  # Since S2b, every addon-gated domain also requires a real
  # ControlPlane::Entitlement row before its controllers respond at all. This
  # institution is meant to behave like a fully-provisioned tenant for RBAC
  # tests (true of every domain test file written before S2b existed), so
  # grant_full_entitlements makes that true again in one place rather than
  # have each domain's test file duplicate it. Tests exercising the
  # entitlement gate ITSELF (test/integration/entitlement_gate_test.rb) revoke
  # the specific domain they need "not entitled" from this default.
  DEFAULT_ROLE_PERMISSIONS = %w[students.read grades.read grades.write counseling.read staff.read].freeze

  def sign_in_as_member(grant_default_role: true)
    slug = "t#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    user = Core::User.create!(email: "#{slug}@member.test", name: "Test Member",
      password: "password-123456")
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      institution.memberships.create!(user: user)
    end
    grant_role!(user, institution: institution, role_key: "member_default",
      permission_keys: DEFAULT_ROLE_PERMISSIONS) if grant_default_role
    grant_full_entitlements(institution)
    sign_in_as(user, institution: institution, password: "password-123456")
    [ user, institution ]
  end

  # Seeds a REAL IdentityAccess::RoleAssignment (+ the Role/RolePermission
  # rows it needs) for `user`'s membership in `institution` — the real
  # replacement for the retired StubAssignments-monkeypatch technique. Same
  # shape as the old Authorization::Assignment.new(role_key:, permission_keys:,
  # scope_type:, scope_id:) calls it replaces, so converting a test is
  # mechanical. role/role_permissions are tenant-scoped+RLS in the real
  # schema (unlike the monolithic doc's original "global" claim — see P1
  # recon), so this runs under the tenant's GUC like membership creation does.
  # scope_department_id/scope_grade_level_id/scope_group_id carry a REAL FK
  # (to departments/grade_levels/sections respectively — confirmed in P1
  # recon, contrary to the "no polymorphic FK" doc wording which read as "no
  # FK at all"), so a scoped grant needs the referenced row to actually
  # exist. Each test runs inside its own rolled-back transaction (Rails'
  # transactional fixtures), so reusing the SAME fixed scope_id constant
  # (e.g. GroupManagement::GroupRoster::SECTION_10A_ID, still stub as of #4
  # slice 1) across many unrelated test institutions is safe — nothing
  # persists between tests to collide on that id.
  def grant_role!(user, institution:, role_key:, permission_keys:, scope_type: :institution, scope_id: nil)
    institution_user = institution.memberships.active.find_by!(user: user)

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)

      role = IdentityAccess::Role.find_or_create_by!(institution: institution, key: role_key.to_s) do |r|
        r.name = role_key.to_s.humanize
      end

      Array(permission_keys).each do |key|
        permission = IdentityAccess::Permission.find_or_create_by!(key: key)
        IdentityAccess::RolePermission.find_or_create_by!(
          institution: institution, role: role, permission: permission
        )
      end

      scope_attrs = case scope_type.to_sym
      when :institution
        {}
      when :department
        StaffManagement::Department.find_or_create_by!(id: scope_id) do |d|
          d.institution = institution
          d.name = "Departamento de prueba"
          d.code = "DPT-#{scope_id[0, 8]}"
          d.kind = "academic"
        end
        { scope_department_id: scope_id }
      when :grade_level
        GroupManagement::GradeLevel.find_or_create_by!(id: scope_id) do |g|
          g.institution = institution
          g.name = "Grado de prueba"
          g.level_number = 0
        end
        { scope_grade_level_id: scope_id }
      when :group
        GroupManagement::Section.find_or_create_by!(id: scope_id) do |s|
          s.institution = institution
          s.name = "Sección de prueba"
          s.academic_year = Date.current.year
        end
        { scope_group_id: scope_id }
      when :route
        Transportation::Route.find_or_create_by!(id: scope_id) do |r|
          r.institution = institution
          r.name = "Ruta de prueba"
        end
        { scope_route_id: scope_id }
      else raise ArgumentError, "unknown scope_type: #{scope_type}"
      end

      IdentityAccess::RoleAssignment.create!(
        institution: institution, institution_user: institution_user, role: role, **scope_attrs
      )
    end
  end

  # Shared real replacement for the retired per-file StubAssignments-
  # monkeypatch technique (every test/integration/*_test.rb used to define
  # its OWN with_grants doing `StubAssignments.define_singleton_method(:all)`
  # — that persona is simply never consulted anymore once IdentityAccess::
  # PermissionCheck exists, see Authorization::Controller). REPLACES the
  # actor's persona for the block, same semantics as the retired technique:
  # first revokes whatever RoleAssignment sign_in_as_member's default already
  # granted (real rows only ADD, they don't override each other, unlike
  # swapping StubAssignments.all wholesale), then seeds each
  # Authorization::Assignment as a real RoleAssignment for @user/@institution
  # (set by sign_in_as_member in the file's setup). Same call shape as
  # before, so a file's own with_grants override can just be deleted.
  # :route (transportation, v1.49.0) is a real scope like the other three —
  # scope_route_id exists on role_assignments and grant_role! seeds it —
  # transportation_test.rb no longer needs with_raw_grants.
  def with_grants(*assignments, &block)
    revoke_all_role_assignments!(@user, institution: @institution)
    assignments.each do |a|
      grant_role!(@user, institution: @institution, role_key: a.role_key,
        permission_keys: a.permission_keys, scope_type: a.scope_type, scope_id: a.scope_id)
    end
    yield
  end

  # Strips every real RoleAssignment the member holds, on the SAME already
  # signed-in institution/user (unlike sign_in_as_member(grant_default_role:
  # false), which would stand up a brand new institution and lose whatever
  # setup — e.g. entitlement revocations — the test already did). Used by the
  # one scenario that needs "zero RBAC grants" on a pre-configured tenant
  # (see test/integration/entitlement_gate_test.rb's gate-order test).
  def revoke_all_role_assignments!(user, institution:)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      institution_user = institution.memberships.active.find_by!(user: user)
      IdentityAccess::RoleAssignment.where(institution_user: institution_user).delete_all
    end
  end

  def grant_full_entitlements(institution)
    Entitlement::Registry.domains.each do |key|
      addon = ControlPlane::Addon.find_or_create_by!(key: key) do |a|
        a.name = key.humanize
        a.currency = "COP"
      end
      # valid_from in the past (never today): Entitlement#revoke! (v1.33.0)
      # closes valid_until at Date.current, which the model rejects when
      # equal to valid_from (mirrors Subscription#end!'s same-day
      # restriction) — many "entitlement gate #1" tests revoke this SAME
      # default grant within the same test, same day it was seeded here.
      ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: 1.day.ago.to_date)
    end
  end
end
