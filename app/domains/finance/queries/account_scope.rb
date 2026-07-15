module Finance
  # #4 canonical mold (§6.6, teacher_management) copied here: real relation +
  # institution_id explicit + per-row can? via .select, never default_scope.
  # Unlike the academic domains (scope by group), treasury is an
  # institution-wide function — every row a "finance.read" grant covers will
  # pass the per-row check, but the discipline (query object, never
  # default_scope, never PermissionCheck#scope_for) stays identical.
  class AccountScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Finance::StudentAccount
        .where(institution_id: institution.id)
        .joins(:student)
        .includes(:student)
        .order("students.last_name, students.first_name")
        .select { |account| context.can?("finance.read", account) }
    end

    private

    attr_reader :context, :institution
  end
end
