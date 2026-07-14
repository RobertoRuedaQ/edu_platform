# Owned by app/domains/attendance. Route lands with the actor's own scoped
# groups (attendance.record) — the daily-by-homeroom take-attendance loop.
Navigation::Registry.register(
  domain: "attendance",
  label: "Asistencia",
  path: "/attendance/groups",
  permission: "attendance.record",
  position: 26
)
