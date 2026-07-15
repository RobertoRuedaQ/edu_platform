# Owned by app/domains/assignments. Route lands with the actor's own scoped
# subjects (assignment.manage) — same "pick a subject first" landing as
# report_cards/attendance's "pick a group first".
Navigation::Registry.register(
  domain: "assignments",
  label: "Tareas",
  path: "/assignments/subjects",
  permission: "assignment.manage",
  position: 31
)
