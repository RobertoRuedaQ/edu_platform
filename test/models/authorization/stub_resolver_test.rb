require "test_helper"

class Authorization::StubResolverTest < ActiveSupport::TestCase
  # Minimal stand-in for a scoped resource (a real model or a presenter struct
  # would expose the same *_id readers the Assignment consults).
  ScopedResource = Struct.new(:department_id, :group_id)

  def dept_grant(dept_id)
    Authorization::Assignment.new(
      role_key: "area_head",
      permission_keys: %w[grades.read grades.write],
      scope_type: :department,
      scope_id: dept_id
    )
  end

  test "allows a permission on a resource inside the granted department scope" do
    resolver = Authorization::StubResolver.new([dept_grant("d-1")])
    assert resolver.can?("grades.write", ScopedResource.new("d-1", nil))
  end

  test "denies the same permission on a resource outside the granted scope" do
    resolver = Authorization::StubResolver.new([dept_grant("d-1")])
    assert_not resolver.can?("grades.write", ScopedResource.new("d-2", nil))
  end

  test "denies a permission the actor was never granted, even in scope" do
    resolver = Authorization::StubResolver.new([dept_grant("d-1")])
    assert_not resolver.can?("finance.write", ScopedResource.new("d-1", nil))
  end

  test "institution-wide grant covers any resource" do
    wide = Authorization::Assignment.new(
      role_key: "admin", permission_keys: %w[grades.write],
      scope_type: :institution, scope_id: nil
    )
    resolver = Authorization::StubResolver.new([wide])
    assert resolver.can?("grades.write", ScopedResource.new("whatever", nil))
  end

  test "capability-only check (no resource) ignores scope" do
    resolver = Authorization::StubResolver.new([dept_grant("d-1")])
    assert resolver.can?("grades.write")
  end

  test "can? returns false (never raises) with no matching grant" do
    resolver = Authorization::StubResolver.new([])
    assert_equal false, resolver.can?("grades.write", ScopedResource.new("d-1", nil))
  end
end
