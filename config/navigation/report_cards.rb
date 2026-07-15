# Owned by app/domains/report_cards. Route lands with the actor's own scoped
# groups (report_card.view) — the same "pick a group first" landing as
# attendance.
Navigation::Registry.register(
  domain: "report_cards",
  label: "Boletines",
  path: "/report_cards/groups",
  permission: "report_card.view",
  position: 27
)
