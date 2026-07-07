module StudentSupport
  class AccommodationScope
    def initialize(context:)
      @context = context
    end

    def resolve
      AccommodationRoster.all.select { |row| @context.can?("accommodations.view", row) }
    end
  end
end
