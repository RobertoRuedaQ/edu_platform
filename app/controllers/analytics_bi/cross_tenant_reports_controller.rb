module AnalyticsBi
  # SOLO bi_auditor. cross_tenant_reports.view must never be bundled into
  # institution_admin or any other role — see the comment on this permission
  # in IdentityAccess::SeedPermissions::CATALOG.
  class CrossTenantReportsController < ApplicationController
    def index
      authorize!("cross_tenant_reports.view")
      @reports = AnalyticsBi::CrossTenantReportRoster.all
    end
  end
end
