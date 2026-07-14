module ControlPlane
  # Canonical list of addon-able domains (F14): the foundational domains
  # (core, teacher_management, group_management, identity_access) are always
  # on and are NEVER addons. Everything else in the domain map is addon-able.
  #
  # This is the ONLY place ControlPlane::Addon#key is validated against — the
  # list lives in code (PROJECT_STATE.md §4), not a DB enum/FK, because
  # domains are code, not rows.
  module AddonCatalog
    DOMAIN_KEYS = %w[
      cafeteria
      transportation
      schedules
      student_support
      counseling
      finance
      communication
      analytics_bi
      attendance
    ].freeze
  end
end
