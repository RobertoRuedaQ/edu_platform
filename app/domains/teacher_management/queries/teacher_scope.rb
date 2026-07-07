module TeacherManagement
  # Filters TeacherRoster to what the actor's scope covers. No default_scope:
  # an explicit, per-row authorization check against the STUB roster, using the
  # SAME seam authorize!/can? use (context.can?), so index filtering and single-
  # resource gating can never disagree.
  class TeacherScope
    def initialize(context:)
      @context = context
    end

    def resolve
      TeacherRoster.all.select { |teacher| @context.can?("teachers.view", teacher) }
    end
  end
end
