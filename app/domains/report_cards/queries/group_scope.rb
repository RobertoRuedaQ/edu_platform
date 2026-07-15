module ReportCards
  # #4 canonical mold (§6.6, teacher_management) copied here: real relation +
  # institution_id explicit + per-row can? via .select, never default_scope.
  # A SEPARATE query object from Attendance::GroupScope/GroupManagement::
  # GroupScope (not reused) — it filters by report_card.view, a DIFFERENT
  # permission than either of those.
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
        .select { |group| context.can?("report_card.view", group) }
    end

    private

    attr_reader :context, :institution
  end
end
