module Assignments
  # Add/edit/remove ONE shared column of a template's matrix — same
  # author-owned scoping as RubricCriteriaController, nested under the
  # template.
  class RubricLevelsController < ApplicationController
    def create
      authorize!("assignment.manage")
      template = find_template
      attrs = level_params.to_h
      attrs[:position] = template.rubric_levels.size if attrs[:position].blank?
      template.rubric_levels.create(attrs.merge(institution: template.institution))
      redirect_to edit_assignments_rubric_template_path(template)
    end

    def update
      authorize!("assignment.manage")
      template = find_template
      template.rubric_levels.find(params[:id]).update(level_params)
      redirect_to edit_assignments_rubric_template_path(template)
    end

    def destroy
      authorize!("assignment.manage")
      template = find_template
      template.rubric_levels.find(params[:id]).destroy!
      redirect_to edit_assignments_rubric_template_path(template)
    end

    private

    def find_template
      template = Assignments::RubricTemplate.find_by(institution_id: Current.institution_id,
        authored_by_user_id: Current.user.id, id: params[:rubric_template_id])
      raise ActiveRecord::RecordNotFound if template.nil?

      template
    end

    def level_params
      params.require(:rubric_level).permit(:label, :points, :position)
    end
  end
end
