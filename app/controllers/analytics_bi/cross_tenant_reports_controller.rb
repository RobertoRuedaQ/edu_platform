module AnalyticsBi
  # SOLO bi_auditor. cross_tenant_reports.view must never be bundled into
  # institution_admin or any other role — see the comment on this permission
  # in IdentityAccess::SeedPermissions::CATALOG.
  #
  # v1.35.0: real cross-tenant query via CrossTenantReportRoster (edu_bi_reader,
  # BYPASSRLS) — every access is audited (BI_DOCUMENT.md §6.1.4), logged under
  # the ACTOR'S OWN institution (they're a tenant staff member with the
  # cross-tenant permission, not a platform_admin — this is NOT
  # ControlPlane::Audit).
  class CrossTenantReportsController < ApplicationController
    def index
      authorize!("cross_tenant_reports.view")
      @reports = AnalyticsBi::CrossTenantReportRoster.all
      IdentityAccess::Audit.log(institution: Current.institution, actor_institution_user: Current.institution_user,
        action: "cross_tenant_report_accessed", metadata: { institutions_returned: @reports.size }, ip: request.remote_ip)
    end
  end
end
