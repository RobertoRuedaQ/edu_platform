module Assignments
  # Index only — molde #4 (§6.6), same shape as Attendance::GroupsController/
  # ReportCards::GroupsController. The bare permission check (no resource)
  # gates the index itself; the per-row can? inside Assignments::SubjectScope
  # decides which subjects show (grade_level-scoped grants cover a subject
  # via its own grade_level_id — no new scope dimension needed).
  class SubjectsController < ApplicationController
    def index
      authorize!("assignment.manage")
      @subjects = Assignments::SubjectScope.new(context: authorization_context).resolve
    end
  end
end
