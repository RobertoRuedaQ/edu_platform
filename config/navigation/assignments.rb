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

# v1.26.0 (slice 4) — the reusable rubric LIBRARY, a sibling entry point
# (not nested under a subject: rubrics are docente-wide, reusable across
# every subject/task). Same permission, capability-only check (no subject
# resource) — see RubricTemplatesController's docstring.
Navigation::Registry.register(
  domain: "assignments",
  label: "Rúbricas",
  path: "/assignments/rubric_templates",
  permission: "assignment.manage",
  position: 32
)
