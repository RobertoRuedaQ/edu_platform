module Portals
  # Attach/serve/remove a file on the student's OWN existing entrega —
  # same relation-gated discipline as StudentSubmissionsController: the read
  # gate (Assignments::StudentView.for(student)) IS the write gate, chained
  # down to an existing Submission (attachments never create one). Out-of-
  # scope assignment/submission/attachment 404s here exactly like it would
  # 404 on #show, never a bare "denied" (§6).
  class StudentAttachmentsController < ApplicationController
    include AttachmentServing

    def create
      submission = find_submission
      result = Assignments::AttachmentAdder.call(submission: submission, file: params[:file],
        attached_by: Current.user)

      if result.error
        redirect_to portal_student_assignment_path(submission.assignment), alert: attachment_error_message(result.error)
      else
        redirect_to portal_student_assignment_path(submission.assignment), notice: "Archivo adjuntado."
      end
    end

    def show
      send_submission_attachment(find_attachment)
    end

    def destroy
      attachment = find_attachment
      assignment = attachment.submission.assignment
      attachment.file.purge
      attachment.destroy!
      redirect_to portal_student_assignment_path(assignment), notice: "Archivo eliminado."
    end

    private

    def find_submission
      student = Core::Access::StudentSelfScope.for(Current.user)
      raise ActiveRecord::RecordNotFound if student.nil?

      assignment = Assignments::StudentView.for(student).find(params[:assignment_id])
      submission = Assignments::StudentView.submission_for(assignment, student)
      raise ActiveRecord::RecordNotFound if submission.nil?

      submission
    end

    def find_attachment
      find_submission.submission_attachments.find(params[:id])
    end
  end
end
