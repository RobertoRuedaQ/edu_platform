# frozen_string_literal: true

module ControlPlane
  # Screen 4 — Entitlement editor for one institution: enable/disable addon +
  # dating + negotiated override. Toggles are VISUAL only (no submit this phase).
  # This is gate #1 of the two serial gates; RBAC (identity_access) is gate #2.
  class EntitlementsController < BaseController
    def index
      @institution = Stubs::Fixtures.institution(params[:institution_id] || 1)
      @entitlements = Stubs::Fixtures.entitlements_for(@institution)
    end
  end
end
