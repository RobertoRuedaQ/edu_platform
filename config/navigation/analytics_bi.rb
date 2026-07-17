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

# HPS Lens 1 — "Mapa de Empatía Espacial" (v1.36.0, BI_DOCUMENT.md Slice 2).
# Supervision surface, gated by hps.classroom.view (tenant-scoped, never
# cross-tenant). Sits between the dashboard and the BI audit entry.
Navigation::Registry.register(
  domain: "analytics_bi",
  label: "Mapa del aula",
  path: "/analytics_bi/spatial_classrooms",
  permission: "hps.classroom.view",
  position: 70
)
