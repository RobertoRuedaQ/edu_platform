# Owned by app/domains/cafeteria. Checkout/balances are reached via links
# from the menu page, not their own nav entries — same call as
# departments/groups/rooms in earlier domains.
Navigation::Registry.register(
  domain: "cafeteria",
  label: "Cafetería",
  path: "/cafeteria/menu",
  permission: "menu.view",
  position: 55
)
