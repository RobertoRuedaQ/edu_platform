module IdentityAccess
  # STUB membership directory — Core::User/Core::InstitutionUser are real but
  # carry no seed data (same gap as every other domain by now). Shaped to
  # match identity_access/_user_identity_card's locals directly.
  #
  # TODO: reemplazar por Core::InstitutionUser real + IdentityAccess::RoleAssignment.
  module UserRoster
    RoleGrant = Data.define(:role_name, :scope_label, :system)
    Row = Data.define(:id, :name, :email, :roles)

    def self.all
      [
        Row.new(id: "iu-1", name: "Laura Gómez Duarte", email: "laura.gomez@colegio.test",
                roles: [
                  RoleGrant.new(role_name: "Docente", scope_label: "9°A", system: false),
                  RoleGrant.new(role_name: "Director de grupo", scope_label: "9°A", system: false)
                ]),
        Row.new(id: "iu-2", name: "Andrés Felipe Gómez", email: "andres.gomez@colegio.test",
                roles: [
                  RoleGrant.new(role_name: "Administrador de institución",
                                scope_label: "Toda la institución", system: true)
                ]),
        Row.new(id: "iu-3", name: "Camila Vargas", email: "camila.vargas@colegio.test", roles: [])
      ]
    end

    def self.find(id)
      all.find { |user| user.id == id.to_s }
    end
  end
end
