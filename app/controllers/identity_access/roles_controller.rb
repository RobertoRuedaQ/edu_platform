module IdentityAccess
  class RolesController < ApplicationController
    before_action :set_role, only: %i[show edit update]

    def index
      authorize!("roles.manage")
      @roles = IdentityAccess::Role.where(institution_id: Current.institution_id).order(:name)
    end

    def show
      authorize!("roles.manage", @role)
      @permission_keys = @role.permissions.order(:key).pluck(:key)
    end

    def new
      authorize!("roles.manage")
      @role = IdentityAccess::Role.new
    end

    def create
      authorize!("roles.manage")
      @role = IdentityAccess::Role.new(role_params.merge(institution: Current.institution, system: false,
        key: derive_key(role_params[:name])))
      if @role.save
        sync_permissions(@role)
        redirect_to identity_access_role_path(@role), notice: "Rol creado."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @role.errors.add(:name, "ya existe un rol con un nombre muy similar")
      render :new, status: :unprocessable_entity
    end

    # Roles system: true (institution_admin, sembrado al aprovisionar) nunca
    # se editan desde aquí — molde Library::ResourceCopiesController
    # rechazando a mano la transición "loaned".
    def edit
      authorize!("roles.manage", @role)
      return reject_system_role if @role.system?
    end

    def update
      authorize!("roles.manage", @role)
      return reject_system_role if @role.system?

      if @role.update(role_params)
        sync_permissions(@role)
        redirect_to identity_access_role_path(@role), notice: "Rol actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_role
      @role = IdentityAccess::Role.find_by!(institution_id: Current.institution_id, id: params[:id])
    end

    def reject_system_role
      redirect_to identity_access_role_path(@role), alert: "Los roles de sistema no se pueden editar."
    end

    def role_params
      params.require(:role).permit(:name, :description)
    end

    # key es estable una vez creado el rol — nunca se regenera en #update
    # (podría romper cualquier lookup futuro por key, y renombrar un rol no
    # debería desestabilizar su identificador).
    def derive_key(name)
      name.to_s.parameterize(separator: "_")
    end

    # Sin categoría real en Permission (confirmado, no existe la columna) —
    # agrupar por el prefijo antes del primer "." es puramente de
    # presentación, nunca se persiste.
    def sync_permissions(role)
      selected_ids = Array(params.dig(:role, :permission_ids)).reject(&:blank?)
      current_ids = role.role_permissions.pluck(:permission_id).map(&:to_s)

      (current_ids - selected_ids).each do |stale_id|
        role.role_permissions.find_by(permission_id: stale_id)&.destroy
      end
      (selected_ids - current_ids).each do |new_id|
        role.role_permissions.create!(institution: Current.institution, permission_id: new_id)
      end
    end
  end
end
