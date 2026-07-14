module ControlPlane
  # Idempotent demo data for S4 — signs a subscription, grants two
  # entitlements (one non-metered with a fee override, one metered with
  # quota/price overrides), pushes a headcount snapshot, and creates a couple
  # of synthetic usage_daily_rollups. Enough to exercise every invoice line
  # kind end-to-end via `bin/rails control_plane:cut_invoices`. Amounts/dates
  # are EXAMPLES, not real pricing.
  #
  # Requires db/seeds.rb (creates "Colegio San José") and
  # ControlPlane::SeedCatalog (creates the addon/plan catalog) to have run
  # first — this loudly no-ops rather than inventing parallel demo data if
  # either is missing. Run from `bin/rails control_plane:seed_billing_demo`.
  class SeedBillingDemo
    INSTITUTION_SLUG = "colegio-san-jose"
    HEADCOUNT = 640
    AS_OF_DATE = Date.new(2026, 6, 15)
    PERIOD_START = Date.new(2026, 6, 1)
    PERIOD_END = Date.new(2026, 6, 30)

    def self.call
      institution = Core::Institution.find_by(slug: INSTITUTION_SLUG)
      unless institution
        puts "SeedBillingDemo: institución '#{INSTITUTION_SLUG}' no existe — corre bin/rails db:seed primero. Omitido."
        return
      end

      plan = Plan.find_by(key: SeedCatalog::PLAN[:key])
      unless plan
        puts "SeedBillingDemo: catálogo no sembrado — corre bin/rails control_plane:seed_catalog primero. Omitido."
        return
      end

      subscription = Subscription.active.find_by(institution_id: institution.id) ||
        Subscription.sign!(institution: institution, plan: plan, starts_on: PERIOD_START - 6.months)

      grant_entitlement(institution, subscription, key: "counseling", override_monthly_fee_cents: 500_000)
      transportation = grant_entitlement(institution, subscription, key: "transportation",
        override_included_quota: 4_000, override_unit_price_cents: 40)

      snapshot = StudentHeadcountSnapshot.find_or_initialize_by(institution_id: institution.id, as_of_date: AS_OF_DATE)
      snapshot.assign_attributes(headcount: HEADCOUNT, academic_term_label: "2026-1",
        breakdown: { "ejemplo" => HEADCOUNT }, source: "seed_demo")
      snapshot.save!

      [ [ Date.new(2026, 6, 10), 3_200, 40 ], [ Date.new(2026, 6, 20), 2_100, 25 ] ].each do |date, quantity, events|
        rollup = UsageDailyRollup.find_or_initialize_by(institution_id: institution.id,
          addon_id: transportation.id, unit: "check-ins", usage_date: date)
        rollup.total_quantity = quantity
        rollup.event_count = events
        rollup.save!
      end

      puts "SeedBillingDemo: #{institution.name} — suscripción #{subscription.status}, " \
           "2 entitlements con override, headcount=#{HEADCOUNT} al #{AS_OF_DATE}, 2 rollups sintéticos " \
           "(periodo de ejemplo #{PERIOD_START}..#{PERIOD_END})."
    end

    def self.grant_entitlement(institution, subscription, key:, **overrides)
      addon = Addon.find_by!(key: key)
      Entitlement.active.find_by(institution_id: institution.id, addon_id: addon.id) ||
        Entitlement.create!(institution: institution, addon: addon, subscription: subscription,
          valid_from: PERIOD_START - 6.months, **overrides)
      addon
    end
  end
end
