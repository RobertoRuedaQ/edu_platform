# Owned by app/domains/staff_management. Route lands with the staff domain prompt.
Navigation::Registry.register(
  domain: "staff_management",
  label: "Personal",
  path: "/staff_management/staff",
  permission: "staff.read",
  position: 30
)
