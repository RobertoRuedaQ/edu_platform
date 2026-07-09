module Entitlement
  # Declares which domains are addon-gated (vs foundational), on the TENANT
  # side. Domains self-register from config/entitlements/<domain>.rb — same
  # lazy, self-registering pattern as Navigation::Registry, so adding/removing
  # a gated domain never touches this file or Entitlement::Controller.
  #
  # Deliberately does NOT reference ControlPlane::AddonCatalog::DOMAIN_KEYS at
  # runtime — that would couple every tenant request to a control-plane
  # constant. The two lists are cross-checked ONLY by a test
  # (test/models/entitlement/registry_consistency_test.rb), which is the one
  # place allowed to know about both sides.
  class Registry
    DOMAIN_FILES = Rails.root.join("config/entitlements/*.rb").freeze

    class << self
      def register(domain)
        domains << domain.to_s
      end

      def domains
        load_domains! if @domains.nil?
        @domains
      end

      def gated?(domain) = domains.include?(domain.to_s)

      # Clears the cache (tests) so the next access reloads from disk.
      def reset!
        @domains = nil
      end

      private

      def load_domains!
        @domains = []
        Dir.glob(DOMAIN_FILES).sort.each { |file| load file }
      end
    end
  end
end
