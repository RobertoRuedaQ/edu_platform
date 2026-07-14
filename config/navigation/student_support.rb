# Owned by app/domains/student_support. medical_history/accommodations/
# disciplinary_logs are per-student — reached via links from the student's
# own profile (group_management), not their own nav entries, same call as
# departments/groups/rooms in earlier domains.
Navigation::Registry.register(
  domain: "student_support",
  label: "Bienestar",
  path: "/student_support/dashboard",
  permission: "support_dashboard.view",
  position: 45
)
