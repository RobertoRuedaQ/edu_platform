module TeacherManagement
  # Filters DepartmentRoster to what the actor's scope covers. Same pattern as
  # TeacherScope: explicit, per-row can? check — never default_scope.
  class DepartmentScope
    def initialize(context:)
      @context = context
    end

    def resolve
      DepartmentRoster.all.select { |department| @context.can?("departments.view", department) }
    end
  end
end
