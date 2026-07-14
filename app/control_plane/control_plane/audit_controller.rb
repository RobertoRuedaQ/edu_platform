# frozen_string_literal: true

module ControlPlane
  # Screen 8 — Audit log: who / what / when for control-plane actions.
  class AuditController < BaseController
    def index
      @audit_entries = Stubs::Fixtures.audit_entries
    end
  end
end
