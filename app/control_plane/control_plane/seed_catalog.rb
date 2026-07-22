module ControlPlane
  # Idempotent upsert of the initial billing catalog (S1 demo data — amounts
  # are EXAMPLES, not real pricing). Mirrors IdentityAccess::SeedPermissions'
  # shape (find_or_initialize_by + .call). Run from
  # `bin/rails control_plane:seed_catalog`.
  class SeedCatalog
    # One addon per addon-able domain (F14). `metered`/`unit` amounts are
    # EXAMPLES, not real pricing (same disclaimer as the plan/tiers below).
    #
    # M1 closes per-domain, not all at once: a domain is metered here ONLY
    # once its real facturable event is actually wired (S3b, v1.30.0) — never
    # speculatively, so this table never lies about what's really measured.
    # `transportation` was Clase C (cero modelos reales, ningún checkout que
    # emitir) at v1.30.0, so it was flipped to false back then — a seed that
    # promises measurement over nothing real would be misleading. Real since
    # v1.49.0 (`Transportation::BoardingEvent`); metered for real here since
    # OPEN_PROCESS.md item #5 (this slice) wired the actual emit call.
    ADDONS = [
      # cafeteria (OPEN_PROCESS.md item #5, this slice): Cafeteria::
      # PurchaseRecorder emits one "compras" unit per real Purchase (already
      # idempotent by its OWN idempotency_key, never double-counts a resubmit).
      { key: "cafeteria", name: "Cafetería", monthly_fee_cents: 800_000, metered: true, unit: "compras",
        included_quota: 8_000, overage_unit_price_cents: 30 },
      # transportation (OPEN_PROCESS.md item #5, this slice): BoardingEventsController
      # emits one "abordajes" unit per real BoardingEvent row — each scan is
      # its own distinct real-world event, the row's own id is the anchor.
      { key: "transportation", name: "Transporte", monthly_fee_cents: 500_000, metered: true, unit: "abordajes",
        included_quota: 20_000, overage_unit_price_cents: 5 },
      { key: "schedules", name: "Horarios", monthly_fee_cents: 400_000 },
      { key: "student_support", name: "Bienestar estudiantil", monthly_fee_cents: 600_000 },
      { key: "counseling", name: "Consejería", monthly_fee_cents: 600_000 },
      # finance (v1.30.0): Finance::ChargeCreator/PaymentRecorder emit one
      # "transacciones" unit per real charge/payment (never per attempt —
      # both are already idempotent by their OWN idempotency_key).
      { key: "finance", name: "Tesorería/cartera", metered: true, unit: "transacciones",
        included_quota: 3_000, overage_unit_price_cents: 150 },
      { key: "communication", name: "Comunicación", metered: true, unit: "mensajes",
        included_quota: 10_000, overage_unit_price_cents: 20 },
      { key: "analytics_bi", name: "Analítica y BI", monthly_fee_cents: 1_200_000 },
      # attendance (v1.30.0): Attendance::RecordsController#create emits one
      # "registros" unit per AttendanceRecord saved (re-taking the SAME
      # (group, date) reuses the same record id, so it never double-counts).
      { key: "attendance", name: "Asistencia", metered: true, unit: "registros",
        included_quota: 15_000, overage_unit_price_cents: 5 },
      # report_cards (v1.30.0): ReportCards::Publisher emits one "boletines"
      # unit per (student, academic_term) PUBLICADO — keyed on that pair, not
      # the ReportCard row's own id, since re-publishing regenerates the row
      # (delete_all + create!) but must never re-bill the same boletin.
      { key: "report_cards", name: "Boletines", metered: true, unit: "boletines",
        included_quota: 2_000, overage_unit_price_cents: 100 },
      # assignments (v1.30.0): Assignments::SubmissionRecorder emits one
      # "entregas" unit per Submission saved — one per group on a group
      # assignment (the shared row), never per member.
      { key: "assignments", name: "Tareas", metered: true, unit: "entregas",
        included_quota: 5_000, overage_unit_price_cents: 10 },
      # extracurriculars (v1.30.0): first Addon row for this domain — it had
      # none at all before (created after AddonCatalog::DOMAIN_KEYS, never
      # backfilled into this demo seed). Extracurriculars::EnrollmentCreator
      # emits one "inscripciones" unit per NEW active Enrollment (the
      # idempotent re-enroll-while-active path returns before creating one).
      { key: "extracurriculars", name: "Extracurriculares", metered: true, unit: "inscripciones",
        included_quota: 500, overage_unit_price_cents: 200 }
    ].freeze

    PLAN = {
      key: "k12_standard", name: "K-12 Estándar (ejemplo)",
      description: "Plan de demostración — montos de ejemplo, no tarifas reales.",
      base_price_per_student_cents: 300_000,
      tiers: [
        { min_students: 1, max_students: 500, price_per_student_cents: 300_000 },
        { min_students: 501, max_students: 2_000, price_per_student_cents: 250_000 },
        { min_students: 2_001, max_students: nil, price_per_student_cents: 200_000 }
      ]
    }.freeze

    def self.call
      ADDONS.each do |spec|
        addon = Addon.find_or_initialize_by(key: spec[:key])
        addon.assign_attributes(
          name: spec[:name],
          monthly_fee_cents: spec[:monthly_fee_cents] || 0,
          currency: "COP",
          metered: spec[:metered] || false,
          included_quota: spec[:included_quota],
          unit: spec[:unit],
          overage_unit_price_cents: spec[:overage_unit_price_cents]
        )
        addon.save!
      end

      plan = Plan.find_or_initialize_by(key: PLAN[:key])
      plan.assign_attributes(
        name: PLAN[:name], description: PLAN[:description],
        base_price_per_student_cents: PLAN[:base_price_per_student_cents], currency: "COP"
      )
      plan.save!

      PLAN[:tiers].each do |tier_spec|
        tier = plan.price_tiers.find_or_initialize_by(min_students: tier_spec[:min_students])
        tier.assign_attributes(
          max_students: tier_spec[:max_students],
          price_per_student_cents: tier_spec[:price_per_student_cents]
        )
        tier.save!
      end
    end
  end
end
