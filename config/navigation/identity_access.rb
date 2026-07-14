# Owned by app/domains/identity_access. Route lands with the RBAC admin prompt.
Navigation::Registry.register(
  domain: "identity_access",
  label: "Roles y accesos",
  path: "/identity_access/roles",
  permission: "roles.manage",
  position: 90
)

# Audit viewer (onboarding slice 5). The discrepancy inbox is reached via a
# link FROM this page, not its own nav entry — same call already made for
# cafeteria's checkout/balances and group_management's departments/rooms:
# a related-but-secondary view within one domain doesn't need its own slot.
Navigation::Registry.register(
  domain: "identity_access",
  label: "Auditoría",
  path: "/identity_access/audit_events",
  permission: "audit_events.read",
  position: 91
)
