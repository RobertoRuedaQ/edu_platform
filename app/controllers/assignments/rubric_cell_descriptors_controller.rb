module Assignments
  # ONE bulk save for the whole descriptor matrix (criteria × levels) — the
  # "what distinguishes Bueno from Excelente" text per cell. A single POST
  # with a nested hash, same shape as AssignmentsController#grade's
  # scores/group_scores — never a per-cell round trip. Only meaningful for
  # criteria/levels that ALREADY exist (both sides of the matrix must be
  # persisted rows with real ids), so this is edited on the template's
  # #edit page, after criteria/levels have been saved at least once.
  class RubricCellDescriptorsController < ApplicationController
    def update
      authorize!("assignment.manage")
      template = find_template

      (params[:descriptors]&.to_unsafe_h || {}).each do |criterion_id, by_level|
        criterion = template.rubric_criteria.find_by(id: criterion_id)
        next if criterion.nil?

        by_level.each do |level_id, descriptor|
          level = template.rubric_levels.find_by(id: level_id)
          next if level.nil?

          cell = Assignments::RubricCellDescriptor.find_or_initialize_by(rubric_criterion: criterion, rubric_level: level)
          cell.institution = template.institution
          cell.descriptor = descriptor
          cell.save!
        end
      end

      redirect_to edit_assignments_rubric_template_path(template), notice: "Descriptores guardados."
    end

    private

    def find_template
      template = Assignments::RubricTemplate.find_by(institution_id: Current.institution_id,
        authored_by_user_id: Current.user.id, id: params[:rubric_template_id])
      raise ActiveRecord::RecordNotFound if template.nil?

      template
    end
  end
end
