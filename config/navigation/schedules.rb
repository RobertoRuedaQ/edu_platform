# Owned by app/domains/schedules.
Navigation::Registry.register(
  domain: "schedules",
  label: "Calificaciones",
  path: "/schedules/grades",
  permission: "grades.read",
  position: 20
)

Navigation::Registry.register(
  domain: "schedules",
  label: "Mi horario",
  path: "/schedules/my_schedule",
  permission: "schedule.view",
  position: 22
)

# The institutional builder — rooms are reached from within it (a link), not
# as their own nav entry, same call as departments/groups in earlier domains.
Navigation::Registry.register(
  domain: "schedules",
  label: "Horario institucional",
  path: "/schedules/timetable",
  permission: "timetable.manage",
  position: 24
)
