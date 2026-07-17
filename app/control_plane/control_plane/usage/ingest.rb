module ControlPlane
  module Usage
    # The ONE entry point for recording a metered usage event — domain-agnostic
    # (G5/G6): no GUC is ever fixed here, usage_events is a GLOBAL table. This
    # is the seam S3b will call from inside addon-gated domains once M1 closes
    # a real facturable event per domain; S3a exercises it ONLY with synthetic
    # calls, no domain wiring.
    #
    # Idempotent by design (G3): a duplicate (institution, addon, idempotency_key)
    # is a silent no-op, returning the EXISTING event — a caller that re-emits
    # the same event (retry, at-least-once delivery, etc.) never fails or
    # double-counts. Rejects addons that don't exist or aren't metered (G5) —
    # usage is a factual record, not gated by entitlement status.
    class Ingest
      Rejected = Class.new(StandardError)

      def self.call(institution:, addon_key:, unit:, occurred_at:, idempotency_key:, quantity: 1, metadata: {})
        addon = ControlPlane::Addon.find_by(key: addon_key.to_s)
        raise Rejected, "addon desconocido: #{addon_key}" if addon.nil?
        raise Rejected, "addon no medido: #{addon_key}" unless addon.metered?

        existing = ControlPlane::UsageEvent.for_institution_and_addon(institution, addon)
          .find_by(idempotency_key: idempotency_key)
        return existing if existing

        ControlPlane::UsageEvent.create!(
          institution: institution, addon: addon, unit: unit.to_s, quantity: quantity,
          occurred_at: occurred_at, idempotency_key: idempotency_key, metadata: metadata
        )
      end

      # S3b call sites (inside domain services/controllers) use THIS, never
      # .call directly: metering must never break the underlying business
      # action just because an addon isn't seeded/metered yet in a given
      # environment (a fresh dev DB before `control_plane:seed_catalog`, an
      # institution whose plan doesn't carry that addon, etc.) — Rejected is
      # the one documented/expected failure mode, so ONLY it is swallowed;
      # any other error still raises, so a real bug never hides behind this.
      def self.emit(...)
        call(...)
      rescue Rejected
        nil
      end
    end
  end
end
