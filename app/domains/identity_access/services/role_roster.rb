module IdentityAccess
  # STUB role catalog — Role/RolePermission are real but carry no seed data.
  # assignable_scope_types doesn't exist as a real column (roles has no such
  # field); it's a stub-only concept for now, validated for real in
  # AssignmentsController#create — TODO: reemplazar por columna real cuando
  # el modelo la incorpore.
  module RoleRoster
    Row = Data.define(:id, :key, :name, :description, :system, :assignable_scope_types)

    PERMISSIONS_BY_ROLE_KEY = {
      "institution_admin" => %w[roles.manage staff.read staff.write finance.read finance.write],
      "teacher"           => %w[grades.read grades.write schedule.view students.read],
      "group_director"    => %w[students.read grades.read grades.write counseling.read groups.view groups.manage],
      "area_head"         => %w[teachers.view teacher.evaluate departments.view staff.read students.read],
      "counselor"         => %w[counseling.read medical_history.view_summary accommodations.view
                                 disciplinary_logs.manage support_dashboard.view]
    }.freeze

    def self.all
      [
        Row.new(id: "role-1", key: "institution_admin", name: "Administrador de institución",
                description: "Gestiona roles, usuarios y configuración de la institución.",
                system: true, assignable_scope_types: %i[institution]),
        Row.new(id: "role-2", key: "teacher", name: "Docente",
                description: "Dicta clases y registra calificaciones de sus grupos.",
                system: false, assignable_scope_types: %i[group]),
        Row.new(id: "role-3", key: "group_director", name: "Director de grupo",
                description: "Responsable de un grupo: convivencia y seguimiento académico.",
                system: false, assignable_scope_types: %i[group]),
        Row.new(id: "role-4", key: "area_head", name: "Jefe de área",
                description: "Evalúa docentes y coordina un departamento académico.",
                system: false, assignable_scope_types: %i[department]),
        Row.new(id: "role-5", key: "counselor", name: "Orientador/a",
                description: "Gestiona casos de orientación y bienestar estudiantil.",
                system: false, assignable_scope_types: %i[institution group])
      ]
    end

    def self.find(id)
      all.find { |role| role.id == id.to_s }
    end

    def self.permission_keys_for(role)
      PERMISSIONS_BY_ROLE_KEY.fetch(role.key, [])
    end
  end
end
