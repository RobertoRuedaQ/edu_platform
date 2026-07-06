# frozen_string_literal: true

module ControlPlane
  module Stubs
    # One control-plane audit line: who / what / when. Every super-admin action
    # (entitlement toggles, price overrides, plan changes) is auditable.
    #
    # TODO: reemplazar por modelo real (ControlPlane::AuditEntry), escrito por
    #       el rol auditado con BYPASSRLS.
    AuditEntry = Data.define(
      :actor,        # platform admin who acted
      :actor_role,
      :action,       # verb, e.g. "entitlement.enabled"
      :target,       # what it affected, e.g. "Colegio San José · Cafetería"
      :occurred_at,
      :ip
    )
  end
end
