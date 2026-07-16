module Assignments
  # The teacher's OWN write surface for an assignment's materials — RBAC
  # (assignment.manage), never a portal relation. This is the flip side of
  # Assignments::AttachmentsController (entrega attachments, read-only for
  # the teacher): here the teacher creates/removes, and the same
  # authorize! that already gates editing the assignment gates this too —
  # attaching a material is an authorship action, not a separate
  # permission. Allowed while draft/published; blocked once archived
  # (defense in depth would be nice, but there's no "locked" concept at
  # the model layer here the way group_work has one — MaterialAdder is
  # the single enforcement point, same as AttachmentAdder's "archived
  # closes writes" check for entregas).
  class MaterialsController < ApplicationController
    include AttachmentServing

    def create
      subject = find_subject
      assignment = find_assignment(subject)
      authorize!("assignment.manage", subject)

      result = Assignments::MaterialAdder.call(assignment: assignment, file: params[:file], attached_by: Current.user)
      path = assignments_subject_assignment_path(subject, assignment)
      if result.error
        redirect_to path, alert: attachment_error_message(result.error)
      else
        redirect_to path, notice: "Material adjuntado."
      end
    end

    def show
      subject = find_subject
      assignment = find_assignment(subject)
      authorize!("assignment.manage", subject)

      send_attachable_file(assignment.materials.find(params[:id]))
    end

    def destroy
      subject = find_subject
      assignment = find_assignment(subject)
      authorize!("assignment.manage", subject)

      material = assignment.materials.find(params[:id])
      material.file.purge
      material.destroy!
      redirect_to assignments_subject_assignment_path(subject, assignment), notice: "Material eliminado."
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
