module IdentityAccess
  class RolesController < ApplicationController
    def index
      authorize!("roles.manage")
      @roles = IdentityAccess::RoleRoster.all
    end

    def show
      @role = IdentityAccess::RoleRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("roles.manage", @role)
      @permission_keys = IdentityAccess::RoleRoster.permission_keys_for(@role)
    end
  end
end
