# Owned by app/domains/finance. Route lands with the finance domain prompt.
Navigation::Registry.register(
  domain: "finance",
  label: "Cartera",
  path: "/finance",
  permission: "finance.read",
  position: 40
)
