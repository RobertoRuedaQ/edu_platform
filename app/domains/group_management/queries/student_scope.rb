module GroupManagement
  # Filters StudentRoster to what the actor's scope covers (own group,
  # institution-wide, etc.) — no default_scope: explicit per-row can? check
  # against the STUB roster, same seam authorize! uses.
  class StudentScope
    def initialize(context:)
      @context = context
    end

    def resolve
      StudentRoster.all.select { |student| @context.can?("students.read", student) }
    end
  end
end
