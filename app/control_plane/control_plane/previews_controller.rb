# frozen_string_literal: true

module ControlPlane
  # DEV-ONLY component gallery (buildless — no Lookbook, no gem). Renders the
  # control-plane components in isolation with stub data so they can be eyeballed
  # without navigating the real screens. This is NOT an app view.
  #
  # The route is only mounted in development; this guard is belt-and-suspenders.
  class PreviewsController < BaseController
    before_action :dev_only!

    def index
      @addons = Stubs::Fixtures.addons
      @institution = Stubs::Fixtures.institution(1)
      @invoice = Stubs::Fixtures.invoices.first
      @audit = Stubs::Fixtures.audit_entries
    end

    private

    def dev_only!
      raise ActionController::RoutingError, "Not Found" unless Rails.env.development?
    end
  end
end
