# frozen_string_literal: true

module ControlPlane
  # Screen 1 — Platform dashboard: active institutions, MRR, aggregate usage,
  # alerts. All figures are cross-tenant rollups (stub).
  class DashboardController < BaseController
    def show
      @dashboard = Stubs::Fixtures.dashboard
    end
  end
end
