module ReportCards
  # Index only — molde #4 (§6.6), same shape as Attendance::GroupsController.
  # The bare permission check (no resource) gates the index itself; the
  # per-row can? inside ReportCards::GroupScope decides which groups show.
  class GroupsController < ApplicationController
    def index
      authorize!("report_card.view")
      @groups = ReportCards::GroupScope.new(context: authorization_context).resolve
    end
  end
end
