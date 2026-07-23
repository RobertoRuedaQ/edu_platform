module IdentityAccess
  # Real validation, not cosmetic: a role can only be assigned with a scope
  # it actually admits (IdentityAccess::RoleCatalog.assignable_scope_types_for).
  class AssignmentsController < ApplicationController
    def index
      authorize!("roles.manage")
      @assignments = IdentityAccess::RoleAssignment.where(institution_id: Current.institution_id)
        .includes(:role, :scope_department, :scope_grade_level, :scope_group, :scope_route, :academic_term,
          institution_user: :user)
        .order(created_at: :desc)
    end

    # Reachable only from a real person's context (molde el link "Asignar
    # rol" en people/index.html.erb) — asignar "en abstracto" no es un flujo
    # real; sin user_id no hay a quién asignarle nada.
    def new
      authorize!("roles.manage")
      @institution_user = find_institution_user
      @roles = real_roles
      load_scope_options
    end

    def create
      authorize!("roles.manage")
      @institution_user = find_institution_user
      @roles = real_roles
      load_scope_options

      @role = @roles.find_by(id: assignment_params[:role_id])
      if @role.nil?
        flash.now[:alert] = "Selecciona un rol."
        return render :new, status: :unprocessable_entity
      end

      scope_type = submitted_scope_type
      allowed = IdentityAccess::RoleCatalog.assignable_scope_types_for(@role)
      unless allowed.include?(scope_type)
        flash.now[:alert] = "\"#{@role.name}\" no admite el alcance seleccionado " \
                             "(#{scope_type}). Alcances válidos: #{allowed.join(', ')}."
        return render :new, status: :unprocessable_entity
      end

      assignment = IdentityAccess::RoleAssignment.new(
        institution: Current.institution, institution_user: @institution_user, role: @role,
        **scope_attrs,
        valid_from: assignment_params[:valid_from].presence || Date.current,
        valid_until: assignment_params[:valid_until].presence,
        academic_term_id: assignment_params[:academic_term_id].presence
      )
      # requires_new: true -> a SAVEPOINT, so a unique-violation rescue below
      # doesn't poison the request's own transaction (TenantScoped's
      # around_action) — same posture as AcademicTermsController#activate.
      ActiveRecord::Base.transaction(requires_new: true) { assignment.save! }
      redirect_to identity_access_assignments_path, notice: "Rol asignado."
    rescue ActiveRecord::RecordNotUnique
      flash.now[:alert] = "Esta persona ya tiene ese rol con ese mismo alcance."
      render :new, status: :unprocessable_entity
    end

    private

    def find_institution_user
      Current.institution.memberships.active.find_by!(user_id: params[:user_id])
    end

    def real_roles
      IdentityAccess::Role.where(institution_id: Current.institution_id).order(:name)
    end

    def load_scope_options
      @departments = StaffManagement::Department.where(institution_id: Current.institution_id).order(:name)
      @grade_levels = GroupManagement::GradeLevel.where(institution_id: Current.institution_id).order(:level_number)
      @groups = GroupManagement::Section.where(institution_id: Current.institution_id).order(:name)
      @routes = Transportation::Route.where(institution_id: Current.institution_id).order(:name)
      @academic_terms = Core::AcademicTerm.where(institution_id: Current.institution_id).order(starts_on: :desc)
    end

    def submitted_scope_type
      return :department  if assignment_params[:scope_department_id].presence
      return :grade_level if assignment_params[:scope_grade_level_id].presence
      return :group       if assignment_params[:scope_group_id].presence
      return :route       if assignment_params[:scope_route_id].presence

      :institution
    end

    def scope_attrs
      {
        scope_department_id: assignment_params[:scope_department_id].presence,
        scope_grade_level_id: assignment_params[:scope_grade_level_id].presence,
        scope_group_id: assignment_params[:scope_group_id].presence,
        scope_route_id: assignment_params[:scope_route_id].presence
      }
    end

    def assignment_params
      params.fetch(:assignment, {}).permit(:role_id, :scope_department_id, :scope_grade_level_id,
        :scope_group_id, :scope_route_id, :valid_from, :valid_until, :academic_term_id)
    end
  end
end
