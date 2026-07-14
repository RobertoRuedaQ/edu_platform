require "test_helper"

class ControlPlane::PlatformAdminManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery-staple".freeze

  setup do
    @acting_admin = ControlPlane::PlatformAdmin.create!(email: "acting@platform.test", name: "Acting Admin",
      password: PASSWORD, status: "active")
    @other_admin = ControlPlane::PlatformAdmin.create!(email: "other@platform.test", name: "Other Admin",
      password: PASSWORD, status: "active")
    sign_in_as_platform_admin(@acting_admin, password: PASSWORD)
  end

  test "suspending another admin works and is audited" do
    patch suspend_control_plane_platform_admin_path(@other_admin)
    assert_redirected_to control_plane_platform_admins_path
    assert_not @other_admin.reload.active?

    event = ControlPlane::AuditEvent.find_by(action: "platform_admin.suspended", target_id: @other_admin.id)
    assert event.present?
    assert_equal @acting_admin.id, event.platform_admin_id
  end

  test "reactivating a suspended admin works and is audited" do
    @other_admin.suspend!
    patch reactivate_control_plane_platform_admin_path(@other_admin)
    assert_redirected_to control_plane_platform_admins_path
    assert @other_admin.reload.active?
    assert ControlPlane::AuditEvent.exists?(action: "platform_admin.reactivated", target_id: @other_admin.id)
  end

  test "an admin cannot suspend themselves" do
    patch suspend_control_plane_platform_admin_path(@acting_admin)
    assert_redirected_to control_plane_platform_admins_path
    assert @acting_admin.reload.active?
    assert_not ControlPlane::AuditEvent.exists?(action: "platform_admin.suspended", target_id: @acting_admin.id)
  end

  test "the platform cannot be left with zero active admins" do
    @other_admin.suspend!
    # Only @acting_admin remains active; suspending it would zero out the platform.
    patch suspend_control_plane_platform_admin_path(@acting_admin)
    assert_redirected_to control_plane_platform_admins_path
    assert @acting_admin.reload.active?
  end

  test "index lists admins with status" do
    get control_plane_platform_admins_path
    assert_response :success
    assert_select "td", text: @other_admin.email, count: 0 # email is in a <th>, not <td>
    assert_match @other_admin.email, response.body
  end
end
