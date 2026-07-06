# Owned by app/domains/schedules. Route lands with the schedules domain prompt.
Navigation::Registry.register(
  domain: "schedules",
  label: "Calificaciones",
  path: "/schedules/grades",
  permission: "grades.read",
  position: 20
)
