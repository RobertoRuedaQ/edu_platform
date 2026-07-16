module Assignments
  # Add/edit/remove ONE row of a template's matrix — same author-owned
  # scoping as RubricTemplatesController, nested under the template. No
  # separate index/show: the whole matrix renders on the template's #edit.
  class RubricCriteriaController < ApplicationController
    def create
      authorize!("assignment.manage")
      template = find_template
      attrs = criterion_params.to_h
      attrs[:position] = template.rubric_criteria.size if attrs[:position].blank?
      template.rubric_criteria.create(attrs.merge(institution: template.institution))
      redirect_to edit_assignments_rubric_template_path(template)
    end

    def update
      authorize!("assignment.manage")
      template = find_template
      template.rubric_criteria.find(params[:id]).update(criterion_params)
      redirect_to edit_assignments_rubric_template_path(template)
    end

    def destroy
      authorize!("assignment.manage")
      template = find_template
      template.rubric_criteria.find(params[:id]).destroy!
      redirect_to edit_assignments_rubric_template_path(template)
    end

    private

    def find_template
      template = Assignments::RubricTemplate.find_by(institution_id: Current.institution_id,
        authored_by_user_id: Current.user.id, id: params[:rubric_template_id])
      raise ActiveRecord::RecordNotFound if template.nil?

      template
    end

    def criterion_params
      params.require(:rubric_criterion).permit(:name, :weight, :position)
    end
  end
end
