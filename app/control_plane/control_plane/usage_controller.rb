# frozen_string_literal: true

module ControlPlane
  # Screen 6 — Usage / metering: meters against quota. Overage counts EVENTS,
  # never students.
  class UsageController < BaseController
    def show
      @usage_meters = Stubs::Fixtures.usage_meters
    end
  end
end
