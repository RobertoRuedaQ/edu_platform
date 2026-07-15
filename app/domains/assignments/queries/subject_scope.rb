module Assignments
  # #4 canonical mold (§6.6, teacher_management) copied here: real relation +
  # institution_id explicit + per-row can? via .select, never default_scope.
  # Schedules::Subject already has grade_level_id, so a grade_level-scoped
  # RoleAssignment covers it via the EXISTING Authorization::Assignment::
  # SCOPE_READERS[:grade_level] — same mechanism Schedules::
  # GradeEntriesController already relies on for grades.write; no new scope
  # dimension needed.
  class SubjectScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Schedules::Subject
        .where(institution_id: institution.id)
        .order(:name)
        .select { |subject| context.can?("assignment.manage", subject) }
    end

    private

    attr_reader :context, :institution
  end
end
