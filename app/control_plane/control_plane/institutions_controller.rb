# frozen_string_literal: true

module ControlPlane
  # Screen 2 — Institutions: list + detail. The detail shows the plan, enabled
  # addons and the estimated next invoice (stub). `institution_id` is a global
  # FK here, never an RLS scope.
  class InstitutionsController < BaseController
    def index
      @institutions = Stubs::Fixtures.institutions
    end

    def show
      @institution = Stubs::Fixtures.institution(params[:id])
      @entitlements = Stubs::Fixtures.entitlements_for(@institution)
    end
  end
end
