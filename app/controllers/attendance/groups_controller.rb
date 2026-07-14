module Attendance
  # Index only — molde #4 (§6.6). No #show: a bare group page would have
  # nothing real to display beyond the link into RecordsController#new, so
  # the index links straight there.
  class GroupsController < ApplicationController
    def index
      authorize!("attendance.record")
      @groups = Attendance::GroupScope.new(context: authorization_context).resolve
    end
  end
end
