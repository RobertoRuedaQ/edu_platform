module Assignments
  # The reusable rubric LIBRARY — author-owned (this slice; "share with
  # department" is an explicit future decision). RBAC gate is the same
  # assignment.manage the rest of the namespace uses, but as a CAPABILITY
  # check (no resource — a personal library isn't scoped to one subject/
  # grade_level; see Authorization::Assignment#covers?'s documented
  # "resource nil passes on scope" rule). The actual narrowing — "which
  # templates does THIS docente see" — is authored_by_user_id, applied in
  # every finder below, never a model-level default_scope.
  class RubricTemplatesController < ApplicationController
    def index
      authorize!("assignment.manage")
      @templates = own_templates.order(:name)
    end

    def new
      authorize!("assignment.manage")
      @template = Assignments::RubricTemplate.new
    end

    def create
      authorize!("assignment.manage")
      @template = Assignments::RubricTemplate.new(template_params)
      @template.institution = Current.institution
      @template.authored_by = Current.user

      if @template.save
        redirect_to edit_assignments_rubric_template_path(@template), notice: "Rúbrica creada — agrega criterios y niveles."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize!("assignment.manage")
      @template = find_template
      @descriptors = Assignments::RubricCellDescriptor
        .where(rubric_criterion_id: @template.rubric_criteria.map(&:id))
        .each_with_object({}) { |cell, memo| (memo[cell.rubric_criterion_id] ||= {})[cell.rubric_level_id] = cell.descriptor }
    end

    def update
      authorize!("assignment.manage")
      @template = find_template

      if @template.update(template_params)
        redirect_to edit_assignments_rubric_template_path(@template), notice: "Rúbrica actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize!("assignment.manage")
      find_template.destroy!
      redirect_to assignments_rubric_templates_path, notice: "Rúbrica eliminada."
    end

    private

    def own_templates
      Assignments::RubricTemplate.where(institution_id: Current.institution_id, authored_by_user_id: Current.user.id)
    end

    def find_template
      template = own_templates.find_by(id: params[:id])
      raise ActiveRecord::RecordNotFound if template.nil?

      template
    end

    def template_params
      params.require(:rubric_template).permit(:name)
    end
  end
end
