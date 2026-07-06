# frozen_string_literal: true

module ControlPlane
  # Screen 7 — Billing: invoices + line items in three sections
  # (base_seats / addon_fee / usage_overage). Platform billing the SCHOOL —
  # NOT the finance domain.
  class InvoicesController < BaseController
    def index
      @invoices = Stubs::Fixtures.invoices
    end
  end
end
