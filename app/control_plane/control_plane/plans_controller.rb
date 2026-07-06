# frozen_string_literal: true

module ControlPlane
  # Screen 5 — Plans & pricing: per-student base rate + volume brackets, addon
  # fees, quota + overage. The three hybrid-billing pieces shown side by side.
  class PlansController < BaseController
    def index
      @plans = Stubs::Fixtures.plans
      @addons = Stubs::Fixtures.addons
    end
  end
end
