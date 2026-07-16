module Portals
  # Read-only: the teacher writes materials (RBAC, Assignments::
  # MaterialsController) — the student portal only serves them, gated by
  # the SAME Assignments::StudentView.for(student) scope that already
  # gates #index/#show/entrega attachments. A draft assignment's materials
  # are unreachable for free — the assignment itself isn't in that scope,
  # so #find below 404s before ever touching a material row.
  class StudentMaterialsController < ApplicationController
    include AttachmentServing

    def show
      student = Core::Access::StudentSelfScope.for(Current.user)
      raise ActiveRecord::RecordNotFound if student.nil?

      assignment = Assignments::StudentView.for(student).find(params[:assignment_id])
      send_attachable_file(assignment.materials.find(params[:id]))
    end
  end
end
