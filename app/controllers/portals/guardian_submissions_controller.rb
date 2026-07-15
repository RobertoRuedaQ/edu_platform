module Portals
  # Submitting ON BEHALF of a child (B1: a minor with no login has no other
  # way to submit) — same relation-gated discipline as
  # StudentSubmissionsController: Core::Access::GuardianScope resolves the
  # ONLY children this actor may act for, and Assignments::StudentView.for
  # (that child) resolves the ONLY assignments they may submit to. Both
  # scopes chain — never a bare params[:student_id]/params[:assignment_id]
  # trusted directly. submitted_by_user is the guardian's OWN user (the
  # submission still belongs to the student, see Submission's docstring).
  class GuardianSubmissionsController < ApplicationController
    def create
      student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      assignment = Assignments::StudentView.for(student).find(params[:assignment_id])
      Assignments::SubmissionRecorder.call(assignment: assignment, student: student,
        body: params[:body], submitted_by: Current.user)

      redirect_to portal_guardian_student_assignment_path(student, assignment), notice: "Entrega guardada."
    end
  end
end
