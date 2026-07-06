# frozen_string_literal: true

module ControlPlane
  module Stubs
    # Canned, hardcoded data for the control-plane screens. This is the ONLY
    # place the stub values live, so wiring real queries later means replacing
    # this module and nothing in the controllers/views.
    #
    # NOTHING here touches the database, RLS, or any tenant. All amounts are in
    # the same currency for readability; real billing pulls per-institution.
    #
    # TODO: reemplazar por queries reales (rol auditado BYPASSRLS, cross-tenant).
    module Fixtures
      CURRENCY = "USD"

      module_function

      # -- Catalog -----------------------------------------------------------
      # Addon = domain 1:1. Metered addons meter EVENTS (never students).
      def addons
        [
          Addon.new(key: "analytics_bi", name: "Analítica y BI", domain: "analytics_bi",
                    status: "available", monthly_fee: 120, currency: CURRENCY,
                    metered: true, unit: "consultas", quota: 50_000),
          Addon.new(key: "cafeteria", name: "Cafetería", domain: "cafeteria",
                    status: "available", monthly_fee: 80, currency: CURRENCY,
                    metered: true, unit: "transacciones", quota: 20_000),
          Addon.new(key: "transportation", name: "Transporte", domain: "transportation",
                    status: "available", monthly_fee: 95, currency: CURRENCY,
                    metered: true, unit: "eventos GPS", quota: 200_000),
          Addon.new(key: "counseling", name: "Consejería", domain: "counseling",
                    status: "available", monthly_fee: 60, currency: CURRENCY,
                    metered: false, unit: nil, quota: nil),
          Addon.new(key: "staff_management", name: "Gestión de personal", domain: "staff_management",
                    status: "available", monthly_fee: 70, currency: CURRENCY,
                    metered: false, unit: nil, quota: nil),
          Addon.new(key: "schedules", name: "Horarios", domain: "schedules",
                    status: "beta", monthly_fee: 40, currency: CURRENCY,
                    metered: false, unit: nil, quota: nil),
          Addon.new(key: "teacher_management", name: "Gestión docente (legado)", domain: "teacher_management",
                    status: "deprecated", monthly_fee: 0, currency: CURRENCY,
                    metered: false, unit: nil, quota: nil)
        ]
      end

      def addon(key) = addons.find { |a| a.key == key.to_s }

      # -- Institutions ------------------------------------------------------
      def institutions
        [
          Institution.new(id: 1, name: "Colegio San José", plan_name: "Crecimiento", plan_key: "growth",
                          subscription_status: "active", status: "active", students_count: 1_240,
                          mrr: 3_720, currency: CURRENCY,
                          enabled_addon_names: [ "Analítica y BI", "Cafetería", "Consejería" ],
                          next_invoice_estimate: 4_180),
          Institution.new(id: 2, name: "Liceo Moderno", plan_name: "Base", plan_key: "starter",
                          subscription_status: "trialing", status: "active", students_count: 430,
                          mrr: 1_290, currency: CURRENCY,
                          enabled_addon_names: [ "Cafetería" ],
                          next_invoice_estimate: 1_450),
          Institution.new(id: 3, name: "Instituto Andes", plan_name: "Institucional", plan_key: "enterprise",
                          subscription_status: "past_due", status: "active", students_count: 3_100,
                          mrr: 8_060, currency: CURRENCY,
                          enabled_addon_names: [ "Analítica y BI", "Transporte", "Cafetería", "Gestión de personal" ],
                          next_invoice_estimate: 9_240),
          Institution.new(id: 4, name: "Colegio del Valle", plan_name: "Base", plan_key: "starter",
                          subscription_status: "canceled", status: "suspended", students_count: 210,
                          mrr: 0, currency: CURRENCY,
                          enabled_addon_names: [],
                          next_invoice_estimate: 0)
        ]
      end

      def institution(id) = institutions.find { |i| i.id.to_s == id.to_s }

      # -- Entitlements (institution × addon) --------------------------------
      def entitlements_for(institution)
        name = institution.name
        [
          Entitlement.new(institution_name: name, addon_key: "analytics_bi", addon_name: "Analítica y BI",
                          enabled: true, valid_from: Date.new(2026, 1, 1), valid_until: nil,
                          override_fee: nil, override_quota: nil, currency: CURRENCY),
          Entitlement.new(institution_name: name, addon_key: "cafeteria", addon_name: "Cafetería",
                          enabled: true, valid_from: Date.new(2026, 2, 1), valid_until: Date.new(2026, 12, 31),
                          override_fee: 65, override_quota: 30_000, currency: CURRENCY),
          Entitlement.new(institution_name: name, addon_key: "transportation", addon_name: "Transporte",
                          enabled: false, valid_from: nil, valid_until: nil,
                          override_fee: nil, override_quota: nil, currency: CURRENCY),
          Entitlement.new(institution_name: name, addon_key: "counseling", addon_name: "Consejería",
                          enabled: true, valid_from: Date.new(2026, 3, 15), valid_until: nil,
                          override_fee: nil, override_quota: nil, currency: CURRENCY),
          Entitlement.new(institution_name: name, addon_key: "schedules", addon_name: "Horarios",
                          enabled: false, valid_from: nil, valid_until: nil,
                          override_fee: nil, override_quota: nil, currency: CURRENCY)
        ]
      end

      # -- Plans & pricing ---------------------------------------------------
      def plans
        [
          Plan.new(key: "starter", name: "Base", status: "available", currency: CURRENCY,
                   brackets: [
                     PriceBracket.new(from: 1, to: 500, per_student: 3.0),
                     PriceBracket.new(from: 501, to: nil, per_student: 2.6)
                   ]),
          Plan.new(key: "growth", name: "Crecimiento", status: "available", currency: CURRENCY,
                   brackets: [
                     PriceBracket.new(from: 1, to: 1_000, per_student: 3.0),
                     PriceBracket.new(from: 1_001, to: 2_500, per_student: 2.4),
                     PriceBracket.new(from: 2_501, to: nil, per_student: 2.0)
                   ]),
          Plan.new(key: "enterprise", name: "Institucional", status: "available", currency: CURRENCY,
                   brackets: [
                     PriceBracket.new(from: 1, to: 2_500, per_student: 2.6),
                     PriceBracket.new(from: 2_501, to: 5_000, per_student: 2.1),
                     PriceBracket.new(from: 5_001, to: nil, per_student: 1.7)
                   ])
        ]
      end

      # -- Usage / metering --------------------------------------------------
      def usage_meters
        [
          UsageMeter.new(label: "Consultas de BI", addon_name: "Analítica y BI", unit: "consultas",
                         used: 41_800, quota: 50_000, threshold: 40_000, currency: CURRENCY,
                         overage_unit_price: 0.002),
          UsageMeter.new(label: "Transacciones de cafetería", addon_name: "Cafetería", unit: "transacciones",
                         used: 22_450, quota: 20_000, threshold: 16_000, currency: CURRENCY,
                         overage_unit_price: 0.01),
          UsageMeter.new(label: "Eventos GPS de transporte", addon_name: "Transporte", unit: "eventos GPS",
                         used: 128_000, quota: 200_000, threshold: 160_000, currency: CURRENCY,
                         overage_unit_price: 0.0005),
          UsageMeter.new(label: "Consejería", addon_name: "Consejería", unit: "casos",
                         used: 320, quota: nil, threshold: nil, currency: CURRENCY,
                         overage_unit_price: nil)
        ]
      end

      # -- Invoices ----------------------------------------------------------
      # Three line KINDS in fixed section order: base_seats, addon_fee, usage_overage.
      def invoices
        [
          Invoice.new(number: "PLT-2026-0007", institution_name: "Instituto Andes",
                      period_label: "Julio 2026", status: "open", currency: CURRENCY,
                      lines: [
                        InvoiceLine.new(kind: "base_seats", description: "Base por alumno · 1–2.500 @ 2,60",
                                        quantity: 2_500, unit: "alumnos", unit_price: 2.6, amount: 6_500, currency: CURRENCY),
                        InvoiceLine.new(kind: "base_seats", description: "Base por alumno · 2.501–3.100 @ 2,10",
                                        quantity: 600, unit: "alumnos", unit_price: 2.1, amount: 1_260, currency: CURRENCY),
                        InvoiceLine.new(kind: "addon_fee", description: "Analítica y BI",
                                        quantity: 1, unit: "mes", unit_price: 120, amount: 120, currency: CURRENCY),
                        InvoiceLine.new(kind: "addon_fee", description: "Transporte",
                                        quantity: 1, unit: "mes", unit_price: 95, amount: 95, currency: CURRENCY),
                        InvoiceLine.new(kind: "addon_fee", description: "Cafetería",
                                        quantity: 1, unit: "mes", unit_price: 80, amount: 80, currency: CURRENCY),
                        InvoiceLine.new(kind: "usage_overage", description: "Cafetería · 2.450 transacciones sobre cupo",
                                        quantity: 2_450, unit: "transacciones", unit_price: 0.01, amount: 24.5, currency: CURRENCY)
                      ])
        ]
      end

      # -- Audit -------------------------------------------------------------
      def audit_entries
        [
          AuditEntry.new(actor: "ana.super@plataforma", actor_role: "platform_admin",
                         action: "entitlement.enabled", target: "Colegio San José · Consejería",
                         occurred_at: Time.utc(2026, 7, 5, 14, 32), ip: "190.0.12.4"),
          AuditEntry.new(actor: "ana.super@plataforma", actor_role: "platform_admin",
                         action: "entitlement.override_set", target: "Colegio San José · Cafetería (fee 65, cupo 30.000)",
                         occurred_at: Time.utc(2026, 7, 5, 14, 30), ip: "190.0.12.4"),
          AuditEntry.new(actor: "carlos.ops@plataforma", actor_role: "platform_admin",
                         action: "plan.changed", target: "Instituto Andes → Institucional",
                         occurred_at: Time.utc(2026, 7, 4, 9, 15), ip: "201.6.44.9"),
          AuditEntry.new(actor: "carlos.ops@plataforma", actor_role: "platform_admin",
                         action: "invoice.finalized", target: "PLT-2026-0007 · Instituto Andes",
                         occurred_at: Time.utc(2026, 7, 1, 6, 0), ip: "201.6.44.9")
        ]
      end

      # -- Dashboard rollup --------------------------------------------------
      def dashboard
        insts = institutions
        Dashboard.new(
          active_institutions: insts.count(&:active?),
          total_students: insts.sum(&:students_count),
          mrr: insts.sum(&:mrr),
          currency: CURRENCY,
          usage_meters: usage_meters.first(3),
          alerts: [
            Alert.new(level: "danger", title: "1 factura vencida",
                      detail: "Instituto Andes · PLT-2026-0007 lleva 6 días vencida."),
            Alert.new(level: "warning", title: "Cupo superado",
                      detail: "Cafetería superó el cupo en 2.450 transacciones este período."),
            Alert.new(level: "info", title: "Addon en desuso",
                      detail: "Gestión docente (legado) está deprecado y sin instituciones activas.")
          ],
          recent_audit: audit_entries.first(3)
        )
      end
    end
  end
end
