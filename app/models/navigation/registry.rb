module Navigation
  # Central, data-driven nav registry. Domains SELF-REGISTER their entries from
  # config/navigation/<domain>.rb — adding a domain never touches a shared nav
  # partial or this file, so domains can be built on separate branches without
  # merge conflicts. The shell renders only the entries the actor is allowed to
  # see (filtered by permission), which is what keeps every view ≤ 3 clics away.
  #
  # Registrations load lazily on first access and are cached on the class. In
  # development, editing app code reloads this constant and the entries rebuild;
  # editing ONLY a config/navigation/*.rb file needs a server restart to show.
  class Registry
    DOMAIN_FILES = Rails.root.join("config/navigation/*.rb").freeze

    class << self
      def register(domain:, label:, path:, permission:, position: 100, icon: nil)
        items << Item.new(domain:, label:, path:, permission:, position:, icon:)
      end

      def items
        load_domains! if @items.nil?
        @items
      end

      # Clears the cache (tests) so the next access reloads from disk.
      def reset!
        @items = nil
      end

      # All entries in stable display order (position, then label as tiebreak).
      def sorted
        items.sort_by { |i| [i.position, i.label] }
      end

      # Entries a resolver (anything answering #can?) may see, ordered. Used by
      # tests and the dashboard; the view helper filters with the cosmetic can?.
      def visible_to(resolver)
        sorted.select { |i| resolver.can?(i.permission) }
      end

      private

      def load_domains!
        @items = []
        Dir.glob(DOMAIN_FILES).sort.each { |file| load file }
      end
    end
  end
end
