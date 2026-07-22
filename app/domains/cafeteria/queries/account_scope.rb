module Cafeteria
  # Reuses finance.read (see Cafeteria::BalancesController) and the SAME
  # `Finance::StudentAccount` table Finance::AccountScope already resolves
  # against — a small, honest duplication of that query (molde #4: real
  # relation + institution_id explicit + per-row can?, never default_scope)
  # rather than reaching into `finance`'s own query object to add a
  # cafeteria-only eager load. Institution-wide only, same as Finance::AccountScope
  # — no group/department dimension for treasury.
  class AccountScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Finance::StudentAccount
        .where(institution_id: institution.id)
        .joins(:student)
        .includes(student: :section)
        .order("students.last_name, students.first_name")
        .select { |account| context.can?("finance.read", account) }
    end

    private

    attr_reader :context, :institution
  end
end
