module GroupManagement
  # #4 barrido — copies the teacher_management canonical mold (§6.6): real
  # relation + institution_id explicit + per-row can? via .select, never
  # default_scope. Reads real Section rows now instead of the retired
  # GroupRoster stub.
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
        .select { |group| context.can?("groups.view", group) }
    end

    private

    attr_reader :context, :institution
  end
end
