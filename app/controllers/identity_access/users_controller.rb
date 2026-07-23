module IdentityAccess
  # roles.manage covers users/roles/assignments alike — all three are the
  # same "RBAC admin" capability, institution-scoped (super_admin's
  # cross-tenant view would duplicate control_plane's existing surface, so
  # this stays institution_admin-only, no scoped Query object needed: nothing
  # here is department/group-scoped, it's "everyone in my tenant").
  class UsersController < ApplicationController
    def index
      authorize!("roles.manage")
      @memberships = Current.institution.memberships.includes(:user, role_assignments: :role).order(:created_at)
    end

    def show
      @membership = Current.institution.memberships.includes(:user, role_assignments: :role)
        .find_by(user_id: params[:id])
      raise ActiveRecord::RecordNotFound if @membership.nil?

      authorize!("roles.manage", @membership)
    end
  end
end
