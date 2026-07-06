module Tenant
  # The sharding seam. Today it maps a request -> Institution by subdomain.
  # A future sharded deployment swaps `strategy` for one that ALSO selects a
  # shard/connection — callers never change. Global requests (login, tenant
  # selection, marketing) resolve to nil and run with no tenant set.
  module Resolver
    class SubdomainStrategy
      RESERVED = %w[www app admin api].freeze

      def call(request)
        slug = request.subdomain.to_s.split(".").first
        return if slug.blank? || RESERVED.include?(slug)

        # `institutions` is GLOBAL (no RLS), so this lookup runs fine with no
        # tenant GUC set — exactly the bootstrap moment before we know the tenant.
        Core::Institution.find_by(slug: slug)
      end
    end

    mattr_accessor :strategy, default: SubdomainStrategy.new

    def self.call(request)
      strategy.call(request)
    end
  end
end
