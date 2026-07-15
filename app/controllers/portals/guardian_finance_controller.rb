module Portals
  # Read-only account statement for ONE of the guardian's own children.
  # Security-critical: #show MUST resolve params[:student_id] through
  # Core::Access::GuardianScope, never GroupManagement::Student.find directly
  # — same discipline as GuardianStudentsController/GuardianReportCardsController.
  # No authorize! (GS6/§7) — the scope IS the gate. Same shared read path
  # (Finance::AccountStatement) supervision uses — one computation, two
  # surfaces, so the figures can never disagree. No write action exposed:
  # there is no payment rail, and registering a payment/charge is a
  # supervision-only action.
  class GuardianFinanceController < ApplicationController
    layout "portal"

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      account = Finance::StudentAccount.find_by(institution_id: Current.institution_id, student_id: @student.id)
      @statement = account ? Finance::AccountStatement.call(account) : nil
    end
  end
end
