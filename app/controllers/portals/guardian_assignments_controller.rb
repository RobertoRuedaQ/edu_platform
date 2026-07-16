module Portals
  # Read-only listing + detail, published-only, per-child (like report_cards/
  # finance — a subject's assignments are inherently per-child, unlike
  # org-wide announcements). Both actions MUST resolve params[:student_id]
  # through Core::Access::GuardianScope, never GroupManagement::Student.find
  # directly — a child outside the caller's own scope 404s. The write action
  # (submitting on behalf of the child) lives on GuardianSubmissionsController.
  class GuardianAssignmentsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @assignments = Assignments::StudentView.for(@student)
    end

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @assignment = Assignments::StudentView.for(@student).find(params[:id])
      @submission = Assignments::StudentView.submission_for(@assignment, @student)
      @group = Assignments::StudentView.group_for(@assignment, @student)
    end

    def score_for(assignment)
      Assignments::StudentView.score_for(assignment, @student)
    end
    helper_method :score_for

    def assignment_path_for(assignment)
      portal_guardian_student_assignment_path(@student, assignment)
    end
    helper_method :assignment_path_for

    # attachments (v1.24.0) — one path covers both #show (GET, download)
    # and #destroy (DELETE, quitar); upload is the collection route. Both
    # nest under @student, same as assignment_path_for above.
    def attachment_path_for(attachment)
      portal_guardian_student_assignment_attachment_path(@student, attachment.submission.assignment, attachment)
    end
    helper_method :attachment_path_for

    def attachment_upload_path_for(assignment)
      portal_guardian_student_assignment_attachments_path(@student, assignment)
    end
    helper_method :attachment_upload_path_for
  end
end
