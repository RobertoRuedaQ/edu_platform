module GroupManagement
  # Filters GroupRoster to what the actor's scope covers. Same pattern as
  # StudentScope — never default_scope.
  class GroupScope
    def initialize(context:)
      @context = context
    end

    def resolve
      GroupRoster.all.select { |group| @context.can?("groups.view", group) }
    end
  end
end
