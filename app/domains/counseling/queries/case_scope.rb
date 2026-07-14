module Counseling
  # #4 barrido (v1.14.0, sensitive-domain carve-out — extra care per the
  # domain README's confidentiality boundary). Copies the teacher_management
  # canonical mold (§6.6): real relation + institution_id explicit + per-row
  # can? via .select, never default_scope. RLS is the tenant backstop;
  # counseling.read is the app-layer gate this scope enforces per row.
  class CaseScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Counseling::Case
        .where(institution_id: institution.id)
        .includes(student: :section)
        .order(opened_at: :desc)
        .select { |kase| context.can?("counseling.read", kase) }
    end

    private

    attr_reader :context, :institution
  end
end
