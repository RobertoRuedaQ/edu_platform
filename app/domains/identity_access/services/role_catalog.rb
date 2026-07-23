module IdentityAccess
  # Reemplaza la mitad "código" del stub retirado RoleRoster (el otro lado,
  # datos reales de Role/RolePermission, ahora vive en BD vía RolesController).
  #
  # ASSIGNABLE_SCOPE_TYPES: validación real en AssignmentsController#create,
  # molde exacto lo que el stub ya encodeaba para los 5 roles canónicos.
  # Cualquier OTRO key (un rol custom creado vía la UI nueva) usa
  # DEFAULT_SCOPE_TYPES — no hay forma de inventar una restricción para un
  # rol que el admin acaba de crear, y no se pidió UI para configurarla.
  module RoleCatalog
    DEFAULT_SCOPE_TYPES = %i[institution department grade_level group route].freeze

    ASSIGNABLE_SCOPE_TYPES = {
      "institution_admin" => %i[institution],
      "teacher" => %i[group],
      "group_director" => %i[group],
      "area_head" => %i[department],
      "counselor" => %i[institution group]
    }.freeze

    # Único consumidor real: lib/tasks/qa_seed.rake, para sembrar los 5
    # logins QA de demostración con RBAC real — nunca ofrecido como
    # "plantilla" en la UI de creación de roles (esa UI es libre/custom).
    CANONICAL_ROLES = [
      { key: "institution_admin", name: "Administrador de institución",
        description: "Gestiona roles, usuarios y configuración de la institución.", system: true,
        permission_keys: %w[roles.manage staff.read staff.write finance.read finance.write] },
      { key: "teacher", name: "Docente",
        description: "Dicta clases y registra calificaciones de sus grupos.", system: false,
        permission_keys: %w[grades.read grades.write schedule.view students.read] },
      { key: "group_director", name: "Director de grupo",
        description: "Responsable de un grupo: convivencia y seguimiento académico.", system: false,
        permission_keys: %w[students.read grades.read grades.write counseling.read groups.view groups.manage] },
      { key: "area_head", name: "Jefe de área",
        description: "Evalúa docentes y coordina un departamento académico.", system: false,
        permission_keys: %w[teachers.view teacher.evaluate departments.view staff.read students.read] },
      { key: "counselor", name: "Orientador/a",
        description: "Gestiona casos de orientación y bienestar estudiantil.", system: false,
        permission_keys: %w[counseling.read medical_history.view_summary accommodations.view
                             disciplinary_logs.manage support_dashboard.view] }
    ].freeze

    def self.assignable_scope_types_for(role)
      ASSIGNABLE_SCOPE_TYPES.fetch(role.key, DEFAULT_SCOPE_TYPES)
    end
  end
end
