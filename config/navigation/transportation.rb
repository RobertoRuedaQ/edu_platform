# Owned by app/domains/transportation. Two entries: drivers/route_monitors
# hold boarding.manage but typically NOT routes.view (Apéndice A scopes that
# to transport_coordinator/principal) — without its own nav entry, a driver
# would have no way into their own "today's route" screen at all.
Navigation::Registry.register(
  domain: "transportation",
  label: "Rutas",
  path: "/transportation/routes",
  permission: "routes.view",
  position: 60
)

Navigation::Registry.register(
  domain: "transportation",
  label: "Abordaje",
  path: "/transportation/boarding",
  permission: "boarding.manage",
  position: 62
)
