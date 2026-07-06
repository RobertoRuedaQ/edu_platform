# Owned by app/domains/identity_access. Route lands with the RBAC admin prompt.
Navigation::Registry.register(
  domain: "identity_access",
  label: "Roles y accesos",
  path: "/identity_access/roles",
  permission: "roles.manage",
  position: 90
)
