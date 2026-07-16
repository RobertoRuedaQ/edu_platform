module Portals
  # Attach/serve/remove a file on behalf of a specific child's existing
  # entrega — Core::Access::GuardianScope resolves the ONLY children this
  # actor may act for, then Assignments::StudentView.for(that child)
  # resolves the ONLY assignments/submissions they may touch. Both scopes
  # chain, same discipline as GuardianSubmissionsController — never a bare
  # params[:student_id]/params[:assignment_id] trusted directly.
  # attached_by_user_id records the GUARDIAN who uploaded; the submission
  # still belongs to the child (see Submission's docstring).
  class GuardianAttachmentsController < ApplicationController
    include AttachmentServing

    def create
      student = find_student
      submission = find_submission(student)
      result = Assignments::AttachmentAdder.call(submission: submission, file: params[:file],
        attached_by: Current.user)

      path = portal_guardian_student_assignment_path(student, submission.assignment)
      if result.error
        redirect_to path, alert: attachment_error_message(result.error)
      else
        redirect_to path, notice: "Archivo adjuntado."
      end
    end

    def show
      send_submission_attachment(find_attachment(find_student))
    end

    def destroy
      student = find_student
      attachment = find_attachment(student)
      assignment = attachment.submission.assignment
      attachment.file.purge
      attachment.destroy!
      redirect_to portal_guardian_student_assignment_path(student, assignment), notice: "Archivo eliminado."
    end

    private

    def find_student
      Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
    end

    # A group entrega's submission has no student_id of its own (§0:
    # student XOR group) — resolved via StudentView FOR THIS scoped child
    # regardless, same as StudentView.group_for's "shared entrega" lookup.
    def find_submission(student)
      assignment = Assignments::StudentView.for(student).find(params[:assignment_id])
      submission = Assignments::StudentView.submission_for(assignment, student)
      raise ActiveRecord::RecordNotFound if submission.nil?

      submission
    end

    def find_attachment(student)
      find_submission(student).submission_attachments.find(params[:id])
    end
  end
end
