module Schedules
  class SubjectScope
    def initialize(context:)
      @context = context
    end

    def resolve
      SubjectRoster.all.select { |subject| @context.can?("grades.read", subject) }
    end
  end
end
