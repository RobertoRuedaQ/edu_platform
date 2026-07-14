module IdentityAccess
  # roles.manage covers users/roles/assignments alike — all three are the
  # same "RBAC admin" capability, institution-scoped (super_admin's
  # cross-tenant view would duplicate control_plane's existing surface, so
  # this stays institution_admin-only, no scoped Query object needed: nothing
  # here is department/group-scoped, it's "everyone in my tenant").
  class UsersController < ApplicationController
    def index
      authorize!("roles.manage")
      @users = IdentityAccess::UserRoster.all
    end

    def show
      @user = IdentityAccess::UserRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("roles.manage", @user)
    end
  end
end
