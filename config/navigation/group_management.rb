# Owned by app/domains/group_management. Adding/removing a domain nav entry
# means adding/removing a file here — no shared partial is ever edited.
Navigation::Registry.register(
  domain: "group_management",
  label: "Estudiantes",
  path: "/group_management/students",
  permission: "students.read",
  position: 10
)

# Groups (sections) are a related but distinct index within the same domain —
# two registrations from one domain file is fine; the registry has no
# one-entry-per-domain rule.
Navigation::Registry.register(
  domain: "group_management",
  label: "Grupos",
  path: "/group_management/groups",
  permission: "groups.view",
  position: 15
)
