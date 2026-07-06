# frozen_string_literal: true

module ControlPlane
  module Stubs
    # Cross-tenant rollup for the platform dashboard. Aggregates only — never a
    # tenant-scoped query.
    #
    # TODO: reemplazar por agregados reales (vistas materializadas cross-tenant).
    Dashboard = Data.define(
      :active_institutions,
      :total_students,
      :mrr,
      :currency,
      :usage_meters,   # [UsageMeter] a few headline meters
      :alerts,         # [Alert]
      :recent_audit    # [AuditEntry]
    )
  end
end
