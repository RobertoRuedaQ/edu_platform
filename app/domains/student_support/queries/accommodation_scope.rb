module StudentSupport
  # #4 barrido (real replacement for the AccommodationRoster stub —
  # guidelines/CLOSURE_PLAN.md Fase D). Same molde as
  # StudentSupport::DisciplinaryLogScope/Counseling::CaseScope: real relation
  # + institution_id explicit + per-row can? via .select, never default_scope.
  class AccommodationScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      StudentSupport::Accommodation
        .where(institution_id: institution.id)
        .includes(:student)
        .order(created_at: :desc)
        .select { |row| context.can?("accommodations.view", row) }
    end

    private

    attr_reader :context, :institution
  end
end
