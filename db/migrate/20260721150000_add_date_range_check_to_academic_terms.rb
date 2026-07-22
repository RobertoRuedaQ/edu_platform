class AddDateRangeCheckToAcademicTerms < ActiveRecord::Migration[8.1]
  # guidelines/CLOSURE_PLAN.md §4.2: Core::AcademicTermsController is the first
  # staff-facing surface for this table — until now only db/seeds.rb ever
  # wrote to it, so a bad date range was never actually reachable. The app
  # validation (AcademicTerm#ends_on_after_starts_on) is only a friendly
  # error; this CHECK is the real backstop, same "app validates, DB enforces"
  # discipline as every other table in this codebase.
  def change
    add_check_constraint :academic_terms, "ends_on >= starts_on", name: "academic_terms_date_range_check"
  end
end
