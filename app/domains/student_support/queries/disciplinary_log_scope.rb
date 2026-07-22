module StudentSupport
  # #4 barrido (real replacement for the DisciplinaryLogRoster stub — Class S
  # carve-out, guidelines/CLOSURE_PLAN.md Fase B). Same molde as
  # Counseling::CaseScope: real relation + institution_id explicit + per-row
  # can? via .select, never default_scope. RLS is the tenant backstop;
  # disciplinary_logs.manage is the app-layer gate this scope enforces per row.
  class DisciplinaryLogScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      StudentSupport::DisciplinaryLog
        .where(institution_id: institution.id)
        .includes(:student, reported_by: :user)
        .order(occurred_at: :desc)
        .select { |log| context.can?("disciplinary_logs.manage", log) }
    end

    private

    attr_reader :context, :institution
  end
end
