module Library
  # #4 canonical mold (molde Cafeteria::AccountScope) — real relation +
  # institution_id explicit + per-row can?, never default_scope.
  # Institution-wide only, same as cafeteria/finance: circulation has no
  # group/department dimension to scope by.
  class LoanScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Library::Loan
        .where(institution_id: institution.id)
        .includes(:borrower_student, copy: :resource, borrower_institution_user: :user)
        .order(borrowed_at: :desc)
        .select { |loan| context.can?("library.loans.manage", loan) }
    end

    private

    attr_reader :context, :institution
  end
end
