module Calendar
  # #4 canonical mold (§6.6): real relation + institution_id explicit + per-row
  # can? via .select, never default_scope. The management index for staff: every
  # Calendar::Event of the institution the actor can manage, judged against THAT
  # event's own audience resource (group / grade_level / institution) — the same
  # three-branch resource the controller passes to authorize! on write, so read
  # and write agree on scope. Portal reading never comes through here (see
  # Calendar::VisibleScope, relation-gated, no RBAC).
  class ManageableScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Calendar::Event
        .where(institution_id: institution.id)
        .includes(:grade_level, :group)
        .order(starts_at: :asc)
        .select { |event| context.can?("calendar.manage", audience_resource(event)) }
    end

    private

    attr_reader :context, :institution

    # The resource whose scope id covers?() compares against: a group event ->
    # its Section, a grade event -> its GradeLevel, otherwise the institution
    # (which only an institution-wide grant covers).
    def audience_resource(event)
      return event.group if event.scope_group_id
      return event.grade_level if event.scope_grade_level_id

      institution
    end
  end
end
