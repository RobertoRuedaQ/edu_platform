require "test_helper"

# Test-only controller exercising the hard gate end-to-end: authorize! passing,
# authorize! rescuing into a 403, and can? as a non-raising boolean. Grants are
# fixed here so the test does not depend on the StubAssignments persona.
class AuthorizationGateProbeController < ApplicationController
  # This probe exercises the AUTHORIZATION gate in isolation, with a fixed
  # context (see build_authorization_context below). It is deliberately
  # independent of authentication, so opt out of require_authentication.
  allow_unauthenticated_access

  # Shell-less layout: its 403 render must not pull in the staff shell (which
  # needs an authenticated Current.user). In the real app a 403 only ever fires
  # AFTER authentication, so this only matters for this unauthenticated probe.
  layout "auth"

  def allowed
    authorize!("grades.write")
    render plain: "ok"
  end

  def blocked
    authorize!("finance.write")
    render plain: "ok"
  end

  def peek
    render plain: (can?("finance.write") ? "yes" : "no")
  end

  private

  def build_authorization_context
    Authorization::StubResolver.new([
      Authorization::Assignment.new(
        role_key: "admin", permission_keys: %w[grades.write],
        scope_type: :institution, scope_id: nil
      )
    ])
  end
end

class AuthorizationGateTest < ActionDispatch::IntegrationTest
  def with_probe_routes(&block)
    with_routing do |set|
      set.draw do
        get "probe/allowed" => "authorization_gate_probe#allowed"
        get "probe/blocked" => "authorization_gate_probe#blocked"
        get "probe/peek"    => "authorization_gate_probe#peek"
      end
      block.call
    end
  end

  test "authorize! passes when the actor holds the permission" do
    with_probe_routes do
      get "/probe/allowed"
      assert_response :success
      assert_equal "ok", @response.body
    end
  end

  test "authorize! renders a friendly 403 when the actor lacks the permission" do
    with_probe_routes do
      get "/probe/blocked"
      assert_response :forbidden
      assert_match "No tienes acceso", @response.body
    end
  end

  test "can? reflects the same decision without raising" do
    with_probe_routes do
      get "/probe/peek"
      assert_response :success
      assert_equal "no", @response.body
    end
  end
end
