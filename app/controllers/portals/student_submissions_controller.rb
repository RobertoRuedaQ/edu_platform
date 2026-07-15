module Portals
  # The FIRST write from a portal (v1.22.0) — gated by RELATION, never RBAC,
  # never authorize!. The gate IS Assignments::StudentView.for(@student):
  # the exact same scope that bounds what #index/#show let this student
  # READ also bounds what they can WRITE — an assignment outside that scope
  # (not published, not one of their subjects) 404s here exactly like it
  # would 404 on StudentAssignmentsController#show, never a bare "denied".
  class StudentSubmissionsController < ApplicationController
    def create
      student = Core::Access::StudentSelfScope.for(Current.user)
      raise ActiveRecord::RecordNotFound if student.nil?

      assignment = Assignments::StudentView.for(student).find(params[:assignment_id])
      Assignments::SubmissionRecorder.call(assignment: assignment, student: student,
        body: params[:body], submitted_by: Current.user)

      redirect_to portal_student_assignment_path(assignment), notice: "Entrega guardada."
    end
  end
end
