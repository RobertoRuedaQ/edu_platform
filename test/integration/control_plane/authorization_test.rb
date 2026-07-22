require "test_helper"

# RBAC intra-plano (v1.31.0) — before this slice, ANY active platform_admin
# administered everything. Reads (index/show) stay open to all roles; only
# mutations are gated. `super_admin` is the DEFAULT (backward-compatible —
# every pre-existing/other test's platform_admin keeps full access unless it
# explicitly sets a narrower role, see test_helper.rb-style admins elsewhere).
class ControlPlane::AuthorizationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  def build_admin(role:, email: "admin-#{SecureRandom.hex(4)}@platform.test")
    ControlPlane::PlatformAdmin.create!(email: email, name: "Admin #{role}", password: PASSWORD,
      status: "active", role: role)
  end

  def build_institution
    slug = "auth-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "default role is super_admin (backward-compatible with every pre-existing admin/test)" do
    admin = ControlPlane::PlatformAdmin.create!(email: "legacy@platform.test", name: "Legacy",
      password: PASSWORD, status: "active")
    assert_equal "super_admin", admin.role
  end

  test "viewer: reads succeed everywhere, every mutation is 403" do
    institution = build_institution
    admin = build_admin(role: "viewer")
    sign_in_as_platform_admin(admin, password: PASSWORD)

    get control_plane_addons_path
    assert_response :success
    get control_plane_plans_path
    assert_response :success
    get control_plane_institutions_path
    assert_response :success
    get control_plane_invoices_path
    assert_response :success

    get new_control_plane_addon_path
    assert_response :forbidden
    post control_plane_addons_path, params: { addon: { key: "x", name: "X", currency: "COP" } }
    assert_response :forbidden
    assert_nil ControlPlane::Addon.find_by(key: "x")

    get new_control_plane_plan_path
    assert_response :forbidden
    post control_plane_plans_path, params: { plan: { key: "x", name: "X", base_price_per_student_cents: 1, currency: "COP" } }
    assert_response :forbidden

    get new_control_plane_institution_path
    assert_response :forbidden
    post control_plane_institutions_path, params: { institution: {
      name: "X", slug: "x-#{SecureRandom.hex(3)}", code: "X-1", kind: "school",
      admin_name: "Y", admin_email: "y@x.test"
    } }
    assert_response :forbidden

    get new_control_plane_institution_subscription_path(institution)
    assert_response :forbidden

    get new_control_plane_institution_invoice_path(institution)
    assert_response :forbidden

    other_admin = build_admin(role: "viewer")
    patch suspend_control_plane_platform_admin_path(other_admin)
    assert_response :forbidden
    assert other_admin.reload.active?
  end

  test "billing_ops: can provision institutions and run billing, but NOT touch the catalog or other admins" do
    admin = build_admin(role: "billing_ops")
    sign_in_as_platform_admin(admin, password: PASSWORD)

    post control_plane_institutions_path, params: { institution: {
      name: "Colegio Ops", slug: "colegio-ops-#{SecureRandom.hex(3)}", code: "OPS-1", kind: "school",
      admin_name: "Ana", admin_email: "ana-#{SecureRandom.hex(3)}@ops.test"
    } }
    institution = Core::Institution.find_by!(code: "OPS-1")
    assert_redirected_to control_plane_institution_path(institution)

    get new_control_plane_addon_path
    assert_response :forbidden
    get new_control_plane_plan_path
    assert_response :forbidden

    other_admin = build_admin(role: "viewer")
    patch suspend_control_plane_platform_admin_path(other_admin)
    assert_response :forbidden
  end

  test "super_admin: every mutation succeeds, including managing other platform_admins" do
    admin = build_admin(role: "super_admin")
    sign_in_as_platform_admin(admin, password: PASSWORD)

    other_admin = build_admin(role: "viewer")
    patch suspend_control_plane_platform_admin_path(other_admin)
    assert_redirected_to control_plane_platform_admins_path
    assert_equal "suspended", other_admin.reload.status
  end

  test "the friendly 403 page renders, not a raw exception" do
    admin = build_admin(role: "viewer")
    sign_in_as_platform_admin(admin, password: PASSWORD)

    get new_control_plane_addon_path
    assert_response :forbidden
    assert_match(/No tienes acceso a esta sección/, response.body)
  end
end
