# Owned by app/domains/group_management. Adding/removing a domain nav entry
# means adding/removing a file here — no shared partial is ever edited.
# The real index route lands with the group_management domain prompt.
Navigation::Registry.register(
  domain: "group_management",
  label: "Estudiantes",
  path: "/group_management/students",
  permission: "students.read",
  position: 10
)
