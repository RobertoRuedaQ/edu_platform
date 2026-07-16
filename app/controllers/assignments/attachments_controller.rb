module Assignments
  # Read-only serving for the teacher side — a teacher never uploads here,
  # only views/downloads whatever a student/guardian attached to a roster
  # entrega (§6). Scoped by the SAME assignment.manage authorize! as
  # AssignmentsController, then narrowed to attachments belonging to THIS
  # assignment's own submissions — never a bare SubmissionAttachment.find.
  class AttachmentsController < ApplicationController
    include AttachmentServing

    def show
      subject = find_subject
      assignment = find_assignment(subject)
      authorize!("assignment.manage", subject)

      attachment = Assignments::SubmissionAttachment.joins(:submission)
        .where(institution_id: Current.institution_id, submissions: { assignment_id: assignment.id })
        .find(params[:id])

      send_attachable_file(attachment)
    end

    private

    def find_subject
      subject = Schedules::Subject.find_by(institution_id: Current.institution_id, id: params[:subject_id])
      raise ActiveRecord::RecordNotFound if subject.nil?

      subject
    end

    def find_assignment(subject)
      assignment = Assignments::Assignment.find_by(institution_id: Current.institution_id, subject_id: subject.id,
        id: params[:assignment_id])
      raise ActiveRecord::RecordNotFound if assignment.nil?

      assignment
    end
  end
end
