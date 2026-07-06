# frozen_string_literal: true

module ControlPlane
  # Screen 3 — Addon catalog: visual list/CRUD (no persistence this phase).
  # Addon = domain 1:1.
  class AddonsController < BaseController
    def index
      @addons = Stubs::Fixtures.addons
    end
  end
end
