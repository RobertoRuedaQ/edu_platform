require "test_helper"

class Navigation::RegistryTest < ActiveSupport::TestCase
  # Tiny resolver: allows exactly the given permission keys.
  class FakeResolver
    def initialize(*keys)
      @keys = keys.flatten.map(&:to_s)
    end

    def can?(key, _resource = nil)
      @keys.include?(key.to_s)
    end
  end

  test "loads domain registrations lazily from config/navigation" do
    keys = Navigation::Registry.items.map(&:permission)
    assert_includes keys, "students.read"
    assert_includes keys, "roles.manage"
  end

  test "sorted orders by position (then label)" do
    positions = Navigation::Registry.sorted.map(&:position)
    assert_equal positions.sort, positions
  end

  test "visible_to returns only entries the resolver allows, in display order" do
    resolver = FakeResolver.new("students.read", "counseling.read")
    labels = Navigation::Registry.visible_to(resolver).map(&:label)
    assert_equal ["Estudiantes", "Orientación"], labels
  end

  test "visible_to returns nothing when the resolver allows nothing" do
    assert_empty Navigation::Registry.visible_to(FakeResolver.new)
  end
end
