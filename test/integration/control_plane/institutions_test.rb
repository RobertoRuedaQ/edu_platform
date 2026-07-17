require "test_helper"

class ControlPlane::InstitutionsTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @admin = ControlPlane::PlatformAdmin.create!(email: "admin@platform.test", name: "Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@admin, password: PASSWORD)

    @institution = Core::Institution.create!(name: "Colegio Hub", slug: "colegio-hub",
      code: "HUB-1", kind: "school")
  end

  test "index lists institutions read-only, no create action" do
    get control_plane_institutions_path
    assert_response :success
    assert_match @institution.name, response.body
  end

  test "acceptance: provisioning creates the institution AND bootstraps a real institution_admin" do
    perform_enqueued_jobs do
      post control_plane_institutions_path, params: { institution: {
        name: "Colegio Nuevo", slug: "colegio-nuevo", code: "NEW-1", kind: "school",
        admin_name: "Ana Directora", admin_email: "ana@colegio-nuevo.test"
      } }
    end

    institution = Core::Institution.find_by!(slug: "colegio-nuevo")
    assert_redirected_to control_plane_institution_path(institution)

    # The institution row + its 1:1 settings row (Provisioning::CreateInstitution).
    within_tenant(institution) { assert institution.settings.present? }

    admin_user = Core::User.find_by!(email: "ana@colegio-nuevo.test")
    within_tenant(institution) do
      membership = institution.memberships.find_by!(user_id: admin_user.id)
      role = IdentityAccess::Role.find_by!(institution_id: institution.id, key: "institution_admin")
      assignment = IdentityAccess::RoleAssignment.find_by!(institution_id: institution.id,
        institution_user_id: membership.id, role_id: role.id)
      assert assignment.institution_wide?

      # Every catalog permission except the BI-only cross-tenant escape hatch.
      granted_keys = role.permissions.pluck(:key)
      assert_includes granted_keys, "people.manage" # what actually unblocks onboarding the rest of the staff
      assert_not_includes granted_keys, "cross_tenant_reports.view"
      assert_equal (IdentityAccess::SeedPermissions::CATALOG.keys - %w[cross_tenant_reports.view]).sort, granted_keys.sort
    end

    # A REAL invitation, same path as PeopleController#create.
    within_tenant(institution) do
      invitation = IdentityAccess::Invitation.find_by!(user_id: admin_user.id, institution_id: institution.id)
      assert_equal "sent", invitation.status
    end
    assert_not_empty ActionMailer::Base.deliveries
  end

  test "provisioning without an admin name/email re-renders the form, never creates a half-provisioned institution" do
    post control_plane_institutions_path, params: { institution: {
      name: "Colegio Incompleto", slug: "colegio-incompleto", code: "INC-1", kind: "school",
      admin_name: "", admin_email: ""
    } }
    assert_response :unprocessable_entity
    assert_nil Core::Institution.find_by(slug: "colegio-incompleto")
  end

  test "a duplicate slug is a clean validation error, never a raw RecordNotUnique" do
    post control_plane_institutions_path, params: { institution: {
      name: "Colegio Hub 2", slug: @institution.slug, code: "HUB-2", kind: "school",
      admin_name: "Otro Admin", admin_email: "otro@colegio-hub.test"
    } }
    assert_response :unprocessable_entity
    assert_match(/ya está en uso|has already been taken/i, response.body)
  end

  test "an invalid kind is a clean validation error" do
    post control_plane_institutions_path, params: { institution: {
      name: "Colegio Raro", slug: "colegio-raro", code: "RARO-1", kind: "not_a_real_kind",
      admin_name: "Admin", admin_email: "admin@colegio-raro.test"
    } }
    assert_response :unprocessable_entity
    assert_nil Core::Institution.find_by(slug: "colegio-raro")
  end

  test "show renders without a subscription or entitlements" do
    get control_plane_institution_path(@institution)
    assert_response :success
    assert_match "no tiene una suscripción activa", response.body
  end

  test "show surfaces the active subscription and entitlements once they exist" do
    plan = ControlPlane::Plan.create!(key: "k12_standard", name: "K12 Estándar",
      base_price_per_student_cents: 300_000, currency: "COP")
    ControlPlane::Subscription.sign!(institution: @institution, plan: plan, starts_on: 1.month.ago.to_date)
    addon = ControlPlane::Addon.create!(key: "cafeteria", name: "Cafetería", currency: "COP")
    ControlPlane::Entitlement.create!(institution: @institution, addon: addon, valid_from: Date.current)

    get control_plane_institution_path(@institution)
    assert_response :success
    assert_match "k12_standard".humanize, response.body
    assert_match "Cafetería", response.body
  end

  test "show is read-only for headcount and usage — no snapshots/rollups yet" do
    get control_plane_institution_path(@institution)
    assert_response :success
    assert_match "Sin snapshots de headcount todavía", response.body
    assert_match "Sin uso registrado todavía", response.body
  end

  test "show surfaces headcount snapshots and usage rollups once they exist (S3a)" do
    ControlPlane::StudentHeadcountSnapshot.create!(institution: @institution, as_of_date: Date.current,
      headcount: 42, academic_term_label: "2026-1", breakdown: { "Grado 6" => 42 })
    addon = ControlPlane::Addon.create!(key: "transportation", name: "Transporte", currency: "COP",
      metered: true, unit: "check-ins", included_quota: 100, overage_unit_price_cents: 10)
    ControlPlane::UsageDailyRollup.create!(institution: @institution, addon: addon, unit: "check-ins",
      usage_date: Date.current, total_quantity: 17, event_count: 3)

    get control_plane_institution_path(@institution)
    assert_response :success
    assert_match "42", response.body
    assert_match "2026-1", response.body
    assert_match "Transporte", response.body
    assert_match "17", response.body
  end

  private

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end
end
