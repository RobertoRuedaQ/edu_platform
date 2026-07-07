module Counseling
  class CaseScope
    def initialize(context:)
      @context = context
    end

    def resolve
      CaseRoster.all.select { |kase| @context.can?("counseling.read", kase) }
    end
  end
end
