# Owned by app/domains/calendar. Route lands on the staff management index of
# real calendar events within the actor's scope (calendar.manage). Portal
# timelines (student/guardian) are relation-gated and deliberately NOT here.
Navigation::Registry.register(
  domain: "calendar",
  label: "Calendario",
  path: "/calendar/events",
  permission: "calendar.manage",
  position: 70
)
