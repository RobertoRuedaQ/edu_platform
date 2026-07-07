module StudentSupport
  # Clic 1 for the wellbeing team. Each section is filtered by ITS OWN
  # permission (counseling.read / accommodations.view / disciplinary_logs.manage)
  # via the same can?-based Query objects as everywhere else — holding
  # support_dashboard.view alone never leaks a section the actor lacks the
  # specific permission for.
  class SupportDashboardController < ApplicationController
    def show
      authorize!("support_dashboard.view")

      @open_cases = Counseling::CaseScope.new(context: authorization_context).resolve
                      .reject { |kase| kase.status == "closed" }
      @active_accommodations = StudentSupport::AccommodationScope.new(context: authorization_context).resolve
                                  .select { |row| row.status == "active" }
      @recent_logs = StudentSupport::DisciplinaryLogScope.new(context: authorization_context).resolve
    end
  end
end
