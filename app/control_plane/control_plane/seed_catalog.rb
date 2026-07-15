module ControlPlane
  # Idempotent upsert of the initial billing catalog (S1 demo data — amounts
  # are EXAMPLES, not real pricing). Mirrors IdentityAccess::SeedPermissions'
  # shape (find_or_initialize_by + .call). Run from
  # `bin/rails control_plane:seed_catalog`.
  class SeedCatalog
    # One addon per addon-able domain (F14). `metered` picked for plausibility
    # only — transportation (check-ins) and communication (mensajes) are the
    # two "medidos plausibles" the spec calls out; `unit` stays provisional
    # until M1 closes.
    ADDONS = [
      { key: "cafeteria", name: "Cafetería", monthly_fee_cents: 800_000 },
      { key: "transportation", name: "Transporte", metered: true, unit: "check-ins",
        included_quota: 5_000, overage_unit_price_cents: 50 },
      { key: "schedules", name: "Horarios", monthly_fee_cents: 400_000 },
      { key: "student_support", name: "Bienestar estudiantil", monthly_fee_cents: 600_000 },
      { key: "counseling", name: "Consejería", monthly_fee_cents: 600_000 },
      { key: "finance", name: "Tesorería/cartera", monthly_fee_cents: 700_000 },
      { key: "communication", name: "Comunicación", metered: true, unit: "mensajes",
        included_quota: 10_000, overage_unit_price_cents: 20 },
      { key: "analytics_bi", name: "Analítica y BI", monthly_fee_cents: 1_200_000 },
      { key: "attendance", name: "Asistencia", monthly_fee_cents: 300_000 },
      { key: "report_cards", name: "Boletines", monthly_fee_cents: 400_000 }
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
