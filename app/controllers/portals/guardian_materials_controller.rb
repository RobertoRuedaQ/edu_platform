module Portals
  # Read-only, same chained-scope discipline as GuardianAttachmentsController:
  # Core::Access::GuardianScope resolves the child, then Assignments::
  # StudentView.for(that child) resolves the assignment — two scopes,
  # never a bare params[:student_id]/params[:assignment_id]. A draft
  # assignment's materials are unreachable for free (the assignment itself
  # isn't in that scope yet).
  class GuardianMaterialsController < ApplicationController
    include AttachmentServing

    def show
      student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      assignment = Assignments::StudentView.for(student).find(params[:assignment_id])
      send_attachable_file(assignment.materials.find(params[:id]))
    end
  end
end
