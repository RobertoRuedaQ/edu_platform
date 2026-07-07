module IdentityAccess
  class AssignmentsController < ApplicationController
    def index
      authorize!("roles.manage")
      @assignments = IdentityAccess::RoleAssignmentRoster.all
    end

    def new
      authorize!("roles.manage")
      @user = IdentityAccess::UserRoster.find(params[:user_id]) if params[:user_id].present?
      @roles = IdentityAccess::RoleRoster.all
    end

    # Real validation, not cosmetic: a role can only be assigned with a scope
    # it actually admits (assignable_scope_types). teacher (group-only) can't
    # be granted institution-wide here, even though the form always shows
    # every scope dimension (there's no dynamic JS filtering the options).
    def create
      authorize!("roles.manage")
      @roles = IdentityAccess::RoleRoster.all
      @role = IdentityAccess::RoleRoster.find(params.dig(:assignment, :role_id))

      if @role.nil?
        flash.now[:alert] = "Selecciona un rol."
        render :new, status: :unprocessable_entity
        return
      end

      scope_type = submitted_scope_type
      unless @role.assignable_scope_types.include?(scope_type)
        flash.now[:alert] = "\"#{@role.name}\" no admite el alcance seleccionado " \
                             "(#{scope_type}). Alcances válidos: #{@role.assignable_scope_types.join(', ')}."
        render :new, status: :unprocessable_entity
        return
      end

      # STUB: no persistence yet. TODO: reemplazar por IdentityAccess::RoleAssignment real.
      flash[:notice] = "Rol asignado (stub)."
      redirect_to identity_access_assignments_path
    end

    private

    def submitted_scope_type
      scope = params[:assignment] || {}
      return :department  if scope[:scope_department_id].presence
      return :grade_level if scope[:scope_grade_level_id].presence
      return :group       if scope[:scope_group_id].presence

      :institution
    end
  end
end
