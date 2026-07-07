# Owned by app/domains/analytics_bi. cross_tenant_reports gets its OWN nav
# entry (not a link buried inside institution_dashboard) — a bi_auditor
# typically holds ONLY cross_tenant_reports.view, not institution_dashboard.view
# (same reasoning as transportation's driver needing their own "Abordaje" entry).
Navigation::Registry.register(
  domain: "analytics_bi",
  label: "Analítica",
  path: "/analytics_bi/dashboard",
  permission: "institution_dashboard.view",
  position: 65
)

Navigation::Registry.register(
  domain: "analytics_bi",
  label: "Auditoría BI",
  path: "/analytics_bi/cross_tenant_reports",
  permission: "cross_tenant_reports.view",
  position: 95
)
