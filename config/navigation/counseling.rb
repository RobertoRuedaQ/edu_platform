# Owned by app/domains/counseling. Route lands with the counseling domain prompt.
Navigation::Registry.register(
  domain: "counseling",
  label: "Orientación",
  path: "/counseling",
  permission: "counseling.read",
  position: 50
)
