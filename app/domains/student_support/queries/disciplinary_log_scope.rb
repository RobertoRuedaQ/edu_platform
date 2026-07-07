module StudentSupport
  class DisciplinaryLogScope
    def initialize(context:)
      @context = context
    end

    def resolve
      DisciplinaryLogRoster.all.select { |row| @context.can?("disciplinary_logs.manage", row) }
    end
  end
end
