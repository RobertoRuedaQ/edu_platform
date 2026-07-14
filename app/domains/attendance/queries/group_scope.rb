module Attendance
  # #4 canonical mold (§6.6, teacher_management) copied here: real relation +
  # institution_id explicit + per-row can? via .select, never default_scope.
  # A SEPARATE query object from GroupManagement::GroupScope (not reused)
  # because it filters by a DIFFERENT permission (attendance.record vs.
  # groups.view) — a docente can hold one without the other.
  class GroupScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      GroupManagement::Section
        .where(institution_id: institution.id)
        .includes(:grade_level)
        .order(:name)
        .select { |group| context.can?("attendance.record", group) }
    end

    private

    attr_reader :context, :institution
  end
end
