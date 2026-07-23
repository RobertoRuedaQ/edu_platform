module ControlPlane
  module Billing
    # Assembles a DRAFT invoice for one (institution, period) from the three
    # orthogonal hybrid-billing pieces (§7.3): base_seats + addon_fee +
    # usage_overage. Reads ONLY global control-plane tables — no GUC, no
    # app/domains/* dependency. Never applies to money anything that isn't
    # already frozen: the subscription's SNAPSHOT (never the live plan
    # catalog) and each entitlement's overrides (coalesced over the catalog —
    # this is the moment S2a's stored-but-never-applied overrides finally
    # get used).
    #
    # Idempotent (H1): re-cutting a DRAFT for the same period replaces its
    # lines in place (bulk delete_all, which bypasses InvoiceLineItem's
    # readonly? — a deliberate, whole-draft regeneration is not the same
    # thing as editing one line). Re-cutting a FINALIZED invoice is rejected.
    module PeriodCut
      NoActiveSubscription = Class.new(StandardError)
      AlreadyFinalized = Class.new(StandardError)

      module_function

      def call(institution:, billing_period:)
        period_start = billing_period.starts_on
        period_end = billing_period.ends_on

        # H9 — no contract, no invoice. Checked unconditionally, even on a
        # re-cut: a subscription that has since ended must block it too.
        subscription = ControlPlane::Subscription.active
          .where(institution_id: institution.id)
          .where("starts_on <= ? AND (ends_on IS NULL OR ends_on >= ?)", period_end, period_start)
          .first
        raise NoActiveSubscription, "sin suscripción activa que solape el periodo" if subscription.nil?

        invoice = ControlPlane::Invoice.where(institution_id: institution.id,
          billing_period_id: billing_period.id).where.not(status: "void").first
        raise AlreadyFinalized, "la factura de este periodo ya está finalizada" if invoice&.finalized?

        is_new = invoice.nil?
        invoice ||= ControlPlane::Invoice.new(institution: institution, billing_period: billing_period)

        notes = []
        lines = build_base_seats_line(institution, subscription, period_end, notes)
        lines += build_addon_lines(institution, subscription, period_start, period_end, notes)

        ActiveRecord::Base.transaction do
          invoice.line_items.delete_all if invoice.persisted?
          invoice.assign_attributes(
            subscription: subscription, currency: subscription.currency, notes: notes.presence&.join(" ")
          )
          invoice.save!
          lines.each { |attrs| invoice.line_items.create!(attrs) }
          invoice.recompute_subtotal!
        end

        ControlPlane::Audit.log(action: is_new ? "invoice.drafted" : "invoice.redrafted", target: invoice,
          metadata: { institution_id: institution.id, period_start: period_start.to_s, period_end: period_end.to_s,
                      subtotal_cents: invoice.subtotal_cents })

        invoice
      end

      def build_base_seats_line(institution, subscription, period_end, notes)
        snapshot = ControlPlane::StudentHeadcountSnapshot.for_institution(institution)
          .where("as_of_date <= ?", period_end).order(as_of_date: :desc).first

        unless snapshot
          notes << "Sin snapshot de headcount disponible — línea base_seats omitida."
          return []
        end

        unit_price_cents = PriceResolver.per_student_cents(headcount: snapshot.headcount, subscription: subscription)
        [ {
          kind: "base_seats", addon: nil,
          description: "Base por alumno (#{snapshot.headcount} alumnos)",
          quantity: snapshot.headcount, unit_price_cents: unit_price_cents,
          amount_cents: snapshot.headcount * unit_price_cents,
          source_ref: { "headcount_snapshot_id" => snapshot.id, "as_of_date" => snapshot.as_of_date.to_s }
        } ]
      end

      def build_addon_lines(institution, subscription, period_start, period_end, notes)
        entitlements = ControlPlane::Entitlement.active.where(institution_id: institution.id)
          .where("valid_from <= ? AND (valid_until IS NULL OR valid_until > ?)", period_end, period_start)
          .includes(:addon)

        entitlements.flat_map do |entitlement|
          addon = entitlement.addon
          fee_line = build_addon_fee_line(entitlement, addon, subscription, notes)
          overage_line = addon.metered? ? build_usage_overage_line(institution, entitlement, addon, subscription,
            period_start, period_end, notes) : nil
          [ fee_line, overage_line ].compact
        end
      end

      def build_addon_fee_line(entitlement, addon, subscription, notes)
        unit_price_cents = entitlement.override_monthly_fee_cents || addon.monthly_fee_cents
        flag_currency_mismatch(entitlement.override_currency, subscription.currency, addon.key, notes)

        {
          kind: "addon_fee", addon: addon, description: addon.name,
          quantity: 1, unit_price_cents: unit_price_cents, amount_cents: unit_price_cents,
          source_ref: { "entitlement_id" => entitlement.id,
                        "override_applied" => entitlement.override_monthly_fee_cents.present? }
        }
      end

      def build_usage_overage_line(institution, entitlement, addon, subscription, period_start, period_end, notes)
        usage = ControlPlane::UsageDailyRollup
          .where(institution_id: institution.id, addon_id: addon.id, usage_date: period_start..period_end)
          .sum(:total_quantity)
        quota = entitlement.override_included_quota || addon.included_quota
        overage_quantity = usage - quota
        return if overage_quantity <= 0

        unit_price_cents = entitlement.override_unit_price_cents || addon.overage_unit_price_cents
        flag_currency_mismatch(entitlement.override_currency, subscription.currency, addon.key, notes)

        {
          kind: "usage_overage", addon: addon, description: "#{addon.name} · overage (#{addon.unit})",
          quantity: overage_quantity, unit_price_cents: unit_price_cents,
          amount_cents: overage_quantity * unit_price_cents,
          source_ref: { "entitlement_id" => entitlement.id, "usage_total" => usage, "quota_applied" => quota,
                        "override_applied" => entitlement.override_unit_price_cents.present? }
        }
      end

      def flag_currency_mismatch(override_currency, invoice_currency, addon_key, notes)
        return if override_currency.blank? || override_currency == invoice_currency
        notes << "Moneda de override (#{override_currency}) distinta a la del contrato " \
                 "(#{invoice_currency}) para #{addon_key} — revisar manualmente."
      end
    end
  end
end
