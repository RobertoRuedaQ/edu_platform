module AnalyticsBi
  # Institution-wide KPIs for the actor's OWN tenant only. No Query object:
  # this is a single aggregate for one institution, nothing to filter per row.
  class InstitutionDashboardController < ApplicationController
    def show
      authorize!("institution_dashboard.view")
      @kpis = AnalyticsBi::InstitutionDashboard.for(institution: Current.institution)
    end
  end
end
