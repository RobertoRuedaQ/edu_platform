module IdentityAccess
  # STUB — RoleAssignment is real but carries no seed data. Mirrors its real
  # shape (one row per person × role × scope) closely enough that swapping in
  # the real model later is mechanical.
  # TODO: reemplazar por IdentityAccess::RoleAssignment real.
  module RoleAssignmentRoster
    Row = Data.define(:id, :person_name, :email, :role_name, :role_key, :system, :scope_label, :scope_type)

    def self.all
      [
        Row.new(id: "ra-1", person_name: "Laura Gómez Duarte", email: "laura.gomez@colegio.test",
                role_name: "Docente", role_key: "teacher", system: false,
                scope_label: "9°A", scope_type: :group),
        Row.new(id: "ra-2", person_name: "Laura Gómez Duarte", email: "laura.gomez@colegio.test",
                role_name: "Director de grupo", role_key: "group_director", system: false,
                scope_label: "9°A", scope_type: :group),
        Row.new(id: "ra-3", person_name: "Andrés Felipe Gómez", email: "andres.gomez@colegio.test",
                role_name: "Administrador de institución", role_key: "institution_admin", system: true,
                scope_label: "Toda la institución", scope_type: :institution)
      ]
    end
  end
end
