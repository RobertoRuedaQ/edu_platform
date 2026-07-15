# Owned by app/domains/communication. Publish/manage surface only — reading
# announcements is a membership surface (Communication::FeedController),
# deliberately OUTSIDE this registry (see shared/_announcements_link.html.erb).
Navigation::Registry.register(
  domain: "communication",
  label: "Anuncios (gestión)",
  path: "/communication/announcements",
  permission: "announcement.publish",
  position: 28
)

# v1.20.0 (subsistema B, mensajería). Compose is RBAC — a separate gate from
# the participation-only inbox (Communication::InboxController), which stays
# OUTSIDE this registry, same reasoning as the announcement feed
# (shared/_inbox_link.html.erb, gated by entitlement, not by can?).
Navigation::Registry.register(
  domain: "communication",
  label: "Nueva conversación",
  path: "/communication/conversations/new",
  permission: "conversation.compose",
  position: 29
)

# Deliberately a DIFFERENT permission from compose (§ Guardrails) — an
# institution's comms lead who can start conversations does not thereby
# gain the right to read everyone else's.
Navigation::Registry.register(
  domain: "communication",
  label: "Auditoría de mensajes",
  path: "/communication/conversation_audits",
  permission: "conversation.audit",
  position: 30
)
